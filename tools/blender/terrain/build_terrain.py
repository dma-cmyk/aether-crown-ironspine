"""Build the Ironspine battlefield: heightfield -> Blender meshes -> .blend + .glb.

Run:  blender --background --factory-startup --python tools/blender/terrain/build_terrain.py
Outputs (all regenerated):
  game/assets/terrain/terrain.glb        terrain chunks, water, waterfalls, bridges
  game/assets/terrain/height.bin         float32 [N*N] heights (row = z)
  game/assets/terrain/nav.png            walkable grid (255 = walkable)
  game/assets/terrain/splat.png          RGBA = dirt, rock, ash, forest floor
  game/assets/terrain/minimap.png        tactical map background
  game/assets/terrain/placements.json    trees, rocks, props, mist, bridges
  art/blend/terrain_ironspine.blend      editable Blender scene
  docs/previews/map_overview.png         annotated preview
"""
import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import mapgen  # noqa: E402
import mk  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
LAYOUT = os.path.join(ROOT, "game", "data", "map_ironspine.json")
OUT = os.path.join(ROOT, "game", "assets", "terrain")
BLEND = os.path.join(ROOT, "art", "blend", "terrain_ironspine.blend")
PREV = os.path.join(ROOT, "docs", "previews")
CHUNK = 40  # cells per chunk side


def log(*a):
    print("[terrain]", *a, flush=True)


def mesh_from_arrays(name, verts_g, faces, normals_g=None, colors=None, uvs=None, material=None, uvs2=None):
    """verts_g: (V,3) in Godot space. faces: (F,4|3) index array."""
    vb = np.stack([verts_g[:, 0], -verts_g[:, 2], verts_g[:, 1]], axis=-1)
    me = bpy.data.meshes.new(name)
    me.from_pydata(vb.tolist(), [], faces.tolist())
    me.update()
    if uvs is not None:
        uv = me.uv_layers.new(name="UVMap")
        loop_v = np.empty(len(me.loops), dtype=np.int64)
        me.loops.foreach_get("vertex_index", loop_v)
        uv.data.foreach_set("uv", uvs[loop_v].ravel().astype(np.float32))
        if uvs2 is not None:
            uv2 = me.uv_layers.new(name="UV2")
            uv2.data.foreach_set("uv", uvs2[loop_v].ravel().astype(np.float32))
    if colors is not None:
        ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        ca.data.foreach_set("color", colors.ravel().astype(np.float32))
        me.color_attributes.active_color = ca
        me.color_attributes.render_color_index = 0
    me.polygons.foreach_set("use_smooth", np.ones(len(me.polygons), dtype=bool))
    if normals_g is not None:
        nb = np.stack([normals_g[:, 0], -normals_g[:, 2], normals_g[:, 1]], axis=-1)
        me.normals_split_custom_set_from_vertices(nb.tolist())
    if material is not None:
        me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def grid_faces(rows, cols, cell_mask=None):
    idx = np.arange(rows * cols).reshape(rows, cols)
    a = idx[:-1, :-1]
    b = idx[1:, :-1]
    c = idx[1:, 1:]
    d = idx[:-1, 1:]
    f = np.stack([a, b, c, d], axis=-1)
    if cell_mask is not None:
        f = f[cell_mask]
    return f.reshape(-1, 4)


def build_terrain_chunks(g, H, normals, ao, mat_terrain):
    N = g.N
    S = g.S
    xs = np.linspace(-S / 2, S / 2, N)
    count = 0
    for ci in range(0, N - 1, CHUNK):
        for cj in range(0, N - 1, CHUNK):
            i1 = min(ci + CHUNK, N - 1)
            j1 = min(cj + CHUNK, N - 1)
            sub_h = H[ci:i1 + 1, cj:j1 + 1]
            rows, cols = sub_h.shape
            X, Z = np.meshgrid(xs[cj:j1 + 1], xs[ci:i1 + 1])
            verts = np.stack([X.ravel(), sub_h.ravel(), Z.ravel()], axis=-1)
            nrm = normals[ci:i1 + 1, cj:j1 + 1].reshape(-1, 3)
            a = ao[ci:i1 + 1, cj:j1 + 1].ravel()
            col = np.stack([a, a, a, np.ones_like(a)], axis=-1)
            uv = np.stack([(X.ravel() + S / 2) / S, 1.0 - (Z.ravel() + S / 2) / S], axis=-1)
            faces = grid_faces(rows, cols)
            mesh_from_arrays("terrain_%02d_%02d" % (ci // CHUNK, cj // CHUNK), verts, faces, nrm, col, uv, mat_terrain)
            count += 1
    log("terrain chunks:", count)


def build_water(g, mat_water):
    N = g.N
    S = g.S
    xs = np.linspace(-S / 2, S / 2, N)
    X, Z = np.meshgrid(xs, xs)
    regions = g.water_regions()
    for k, reg in enumerate(regions):
        wet = reg["mask"]
        cells = wet[:-1, :-1] | wet[1:, :-1] | wet[:-1, 1:] | wet[1:, 1:]
        # dilate by one cell so the surface tucks under the canyon walls
        d = cells.copy()
        d[1:, :] |= cells[:-1, :]
        d[:-1, :] |= cells[1:, :]
        d[:, 1:] |= cells[:, :-1]
        d[:, :-1] |= cells[:, 1:]
        # never spill past the crest downstream: test every corner, or the stair-stepped
        # edge pokes out over the waterfall curtain
        sd = g.cf["sd"]
        corners = np.stack([sd[:-1, :-1], sd[1:, :-1], sd[:-1, 1:], sd[1:, 1:]])
        d &= corners.max(axis=0) < reg["hi"] + 0.5
        d &= corners.min(axis=0) > reg["lo"] - 4.0
        if not d.any():
            continue
        faces = grid_faces(N, N, d)
        used = np.unique(faces)
        remap = -np.ones(N * N, dtype=np.int64)
        remap[used] = np.arange(len(used))
        faces = remap[faces]
        vx = X.ravel()[used]
        vz = Z.ravel()[used]
        verts = np.stack([vx, np.full_like(vx, reg["level"]), vz], axis=-1)
        tx = g.cf["tx"].ravel()[used]
        tz = g.cf["tz"].ravel()[used]
        speed = 0.22 if reg["lake"] else 1.0
        col = np.stack([tx * 0.5 + 0.5, tz * 0.5 + 0.5, np.full_like(tx, speed), np.ones_like(tx)], axis=-1)
        nrm = np.tile(np.array([[0.0, 1.0, 0.0]]), (len(used), 1))
        uv = np.stack([vx / 16.0, vz / 16.0], axis=-1)
        mesh_from_arrays("water_%d" % k, verts, faces, nrm, col, uv, mat_water)
    log("water regions:", len(regions))


def curtain(name, rows_pts, mat_fall, width_uv=6.0):
    """rows_pts: list of rows, each row a list of Godot-space points (left->right)."""
    R = len(rows_pts)
    C = len(rows_pts[0])
    verts = np.array([p for row in rows_pts for p in row], dtype=np.float64)
    faces = grid_faces(R, C)
    # uv: u across, v down the fall (arc length based)
    v_len = [0.0]
    for r in range(1, R):
        mid = C // 2
        v_len.append(v_len[-1] + float(np.linalg.norm(np.array(rows_pts[r][mid]) - np.array(rows_pts[r - 1][mid]))))
    total_w = float(np.linalg.norm(np.array(rows_pts[0][-1]) - np.array(rows_pts[0][0])))
    # UV = normalised (across, down); UV2 = texture tiling in metres / width_uv
    uvs = []
    uvs2 = []
    for r in range(R):
        for c in range(C):
            uvs.append((c / (C - 1), v_len[r] / max(v_len[-1], 1e-3)))
            uvs2.append((c / (C - 1) * total_w / width_uv, v_len[r] / width_uv))
    flip = np.array([1.0, -1.0]), np.array([0.0, 1.0])
    uvs = np.array(uvs) * flip[0] + flip[1]
    uvs2 = np.array(uvs2) * flip[0] + flip[1]
    ob = mesh_from_arrays(name, verts, faces, None, None, uvs, mat_fall, uvs2)
    return ob


def build_waterfalls(g, mat_fall, placements):
    for k, wf in enumerate(g.waterfalls()):
        p = wf["center"]
        d = wf["dir"]
        perp = np.array([-d[1], d[0]])
        hw = wf["half_width"]
        rows = []
        nv = 14
        nu = 16
        # flat white-water lip lying on the upper surface (hides the stepped water edge)
        for fwd, dy in ((-3.2, 0.07), (-1.4, 0.08), (0.4, 0.09), (1.6, 0.02)):
            row = []
            for j in range(nu + 1):
                u = -hw * 1.06 + 2 * hw * 1.06 * j / nu
                q = p + perp * u + d * fwd
                row.append((q[0], wf["top"] + dy, q[1]))
            rows.append(row)
        drop = wf["top"] - wf["bottom"] + 0.6
        # widen the arc downstream until the stepped riverbed stays behind the whole curtain
        ts = np.linspace(0.02, 1.0, 60)[:, None]
        us = np.linspace(-hw * 0.85, hw * 0.85, 48)[None, :]  # the faded edges may touch the banks
        ys = wf["top"] + 0.02 - drop * ts ** 1.25
        above = ys > wf["bottom"]
        extra = 0.0
        while extra < 4.0:
            fw = 1.6 + (2.4 + extra) * np.sqrt(ts)
            h = g.height_at(p[0] + perp[0] * us + d[0] * fw, p[1] + perp[1] * us + d[1] * fw)
            if not np.any((h > ys - 0.4) & above):
                break
            extra += 0.2
        for i in range(1, nv + 1):
            t = i / nv
            y = wf["top"] + 0.02 - drop * (t ** 1.25)
            fwd = 1.6 + (2.4 + extra) * math.sqrt(t)
            row = []
            for j in range(nu + 1):
                u = -hw + 2 * hw * j / nu
                q = p + perp * u + d * fwd
                row.append((q[0], y, q[1]))
            rows.append(row)
        curtain("waterfall_%d" % k, rows, mat_fall)
        log("waterfall %d: arc widened by %.1f m" % (k, extra))
        # spray along the foot of the curtain
        n_mist = max(2, int(round(2 * hw / 5.5)))
        for m in range(n_mist):
            u = -hw * 0.85 + 1.7 * hw * (m + 0.5) / n_mist
            q = p + perp * u + d * (4.5 + extra)
            placements["mist"].append([round(float(q[0]), 2), round(wf["bottom"] + 0.4, 2), round(float(q[1]), 2), 3.0])
    for k, cf in enumerate(g.cliff_falls()):
        prof = cf["profile"]
        d = cf["dir"]
        perp = cf["perp"]
        w = cf["width"]
        rows = []
        nu = 6
        # skip leading points on flat plains beyond 3 m from the lip
        for idx, (q, y) in enumerate(prof):
            width = w * (0.45 + 0.55 * min(1.0, idx / 6.0))
            row = []
            for j in range(nu + 1):
                u = (j / nu - 0.5) * width
                pt = q + d * u - perp * 0.45
                row.append((pt[0], y + 0.28, pt[1]))
            rows.append(row)
        curtain("cliff_fall_%d" % k, rows, mat_fall, width_uv=4.0)
        q, y = prof[-1]
        placements["mist"].append([round(float(q[0]), 2), round(cf["water"] + 0.5, 2), round(float(q[1]), 2), round(w * 0.7, 2)])
    log("waterfalls done")


def build_bridge(g, frame, pal):
    a = frame["a"]
    u = frame["u"]
    L = frame["length"]
    W = frame["width"]
    top = frame["deck"]
    w_axis = np.array([-u[1], u[0]])
    ext = 5.0

    def ground(t):
        best = 1e9
        for s in (-0.5, 0.0, 0.5):
            q = a + u * t + w_axis * s * W
            best = min(best, float(g.height_at(q[0], q[1])))
        return best

    ts = np.linspace(-ext, L + ext, 160)
    gs = np.array([ground(t) for t in ts])
    deep = gs < top - 3.0
    if deep.any():
        t_start = float(ts[np.argmax(deep)])
        t_end = float(ts[len(ts) - 1 - np.argmax(deep[::-1])])
    else:
        t_start, t_end = 0.0, L
    span = t_end - t_start
    n_arch = max(1, int(round(span / 15.0)))
    piers = np.linspace(t_start, t_end, n_arch + 1)
    pw = 2.6
    crown_th = 1.5

    def gnd(t):
        return float(np.interp(t, ts, gs))

    pts = [(-ext, top), (L + ext, top)]
    # right abutment down into the ground, then walk left along the bottom
    t = L + ext
    pts.append((t, gnd(t) - 2.0))
    t = t - 2.0
    while t > piers[-1] + pw / 2:
        pts.append((t, gnd(t) - 2.0))
        t -= 2.0
    for k in range(n_arch, 0, -1):
        p_r = piers[k]
        p_l = piers[k - 1]
        pts.append((p_r + pw / 2, min(gnd(p_r + pw / 2), gnd(p_r)) - 1.5))
        pts.append((p_r - pw / 2, min(gnd(p_r - pw / 2), gnd(p_r)) - 1.5))
        half = (p_r - p_l - pw) / 2
        c = (p_r + p_l) / 2
        rise = min(half * 0.95, top - crown_th - (max(gnd(c - half * 0.7), gnd(c), gnd(c + half * 0.7)) + 1.0))
        spring = top - crown_th - max(rise, 0.0)
        if rise > 1.5:
            pts.append((p_r - pw / 2, spring))
            for i in range(1, 16):
                ang = i / 16 * math.pi
                pts.append((c + math.cos(ang) * half, spring + math.sin(ang) * rise))
            pts.append((p_l + pw / 2, spring))
        pts.append((p_l + pw / 2, min(gnd(p_l + pw / 2), gnd(p_l)) - 1.5))
    t = piers[0] - pw / 2
    pts.append((t, gnd(piers[0]) - 1.5))
    t -= 2.0
    while t > -ext:
        pts.append((t, gnd(t) - 2.0))
        t -= 2.0
    pts.append((-ext, gnd(-ext) - 2.0))

    # clean near-duplicate consecutive points
    clean = [pts[0]]
    for p in pts[1:]:
        if abs(p[0] - clean[-1][0]) > 1e-3 or abs(p[1] - clean[-1][1]) > 1e-3:
            clean.append(p)

    b = mk.Builder(frame["id"])
    b.side_profile(clean, W, m=pal["stone"], top_m=pal["paving"], top_edge=0)
    # parapets + merlons
    for side in (-1, 1):
        z = side * (W / 2 - 0.35)
        b.box((L + ext * 2, 1.1, 0.7), (L / 2, top + 0.55, z), pal["stone_trim"])
        n = int((L + ext * 2) / 2.6)
        for i in range(n):
            x = -ext + (i + 0.5) * (L + ext * 2) / n
            b.box((1.0, 0.5, 0.8), (x, top + 1.35, z), pal["stone_trim"])
        # lamps
        for x in np.linspace(0.0, L, max(2, int(L / 13) + 1)):
            b.cylinder(0.11, 3.6, 6, (x, top + 1.1, z), pal["iron"])
            b.box((0.5, 0.6, 0.5), (x, top + 4.9, z), pal["lamp_glow"])
            b.box((0.7, 0.12, 0.7), (x, top + 5.25, z), pal["iron"])
    # pier cutwaters
    for p in piers[1:-1]:
        g0 = gnd(p) - 1.5
        b.cylinder(pw * 0.62, max(1.0, top - 6 - g0), 6, (p, g0, 0), pal["stone"], r2=pw * 0.55)
    ob = b.to_object()
    # place: local x along u, local z across; rotate so +x -> u
    yaw = math.atan2(-u[1], u[0])  # rotation about +Y (Godot) taking +X to u
    ob.matrix_world = mk.G2B @ mk.xform((a[0], 0.0, a[1]), (0.0, math.degrees(yaw), 0.0)) @ mk.G2B.inverted()
    return ob


def annotate_preview(g, img, placements):
    size = img.shape[0]
    S = g.S

    def px(x, z):
        return int((x + S / 2) / S * size), int((z + S / 2) / S * size)

    out = img.copy()
    for t in placements["trees"][::2]:
        i, j = px(t[0], t[2])
        if 0 <= i < size and 0 <= j < size:
            out[j, i] = (out[j, i] * 0.4).astype(np.uint8)
    for s in g.L["sites"]:
        i, j = px(*s["pos"])
        col = {-1: (230, 230, 230), 0: (80, 150, 255), 1: (255, 80, 70)}[s["owner"]]
        out[max(0, j - 4):j + 5, max(0, i - 4):i + 5] = col
    for b in g.L["bases"]:
        i, j = px(*b["pos"])
        col = (60, 130, 255) if b["team"] == 0 else (255, 60, 50)
        out[max(0, j - 7):j + 8, max(0, i - 7):i + 8] = col
    for p in placements["props"]:
        i, j = px(p["pos"][0], p["pos"][2])
        if 0 <= i < size and 0 <= j < size:
            out[j, i] = (255, 210, 120)
    return out


def main():
    t0 = time.time()
    layout = mapgen.load_layout(LAYOUT)
    g = mapgen.MapGen(layout)
    H = g.build_height()
    log("height %.1fs  range %.1f..%.1f" % (time.time() - t0, H.min(), H.max()))
    normals = g.normals()
    ao = g.ambient_occlusion()
    nav = g.build_nav()
    log("nav walkable %.1f%%" % (nav.mean() * 100))
    splat = g.build_splat(layout["splat_size"])
    g.splat_rgba = splat
    log("splat %.1fs" % (time.time() - t0))
    placements = g.build_placements()
    log("placements trees=%d rocks=%d props=%d" % (len(placements["trees"]), len(placements["rocks"]), len(placements["props"])))
    blocked = g.block_props(placements, mapgen.prop_extents(os.path.join(ROOT, "game", "assets", "models"), placements))
    nav = g.nav
    log("nav: %d cells blocked by props, walkable %.1f%%" % (blocked, nav.mean() * 100))

    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREV, exist_ok=True)
    H.astype("<f4").tofile(os.path.join(OUT, "height.bin"))
    mapgen.write_png(os.path.join(OUT, "nav.png"), (nav * 255).astype(np.uint8))
    (nav.astype(np.uint8)).tofile(os.path.join(OUT, "nav.bin"))
    mapgen.write_png(os.path.join(OUT, "splat.png"), splat)
    mini = g.minimap(512)
    mapgen.write_png(os.path.join(OUT, "minimap.png"), mini)

    mk.reset()
    pal = mk.palette()
    mat_terrain = mk.mat("terrain", (0.3, 0.35, 0.22), 0.0, 0.9)
    mat_water = mk.mat("water", (0.1, 0.25, 0.3), 0.0, 0.05)
    mat_fall = mk.mat("waterfall", (0.8, 0.9, 0.95), 0.0, 0.2)
    build_terrain_chunks(g, H, normals, ao, mat_terrain)
    build_water(g, mat_water)
    build_waterfalls(g, mat_fall, placements)
    for fr in g.bridge_frames():
        build_bridge(g, fr, pal)
    log("bridges done")

    meta = {
        "size": g.S, "grid": g.N, "nav_cell": layout["nav_cell"], "nav_size": int(nav.shape[0]),
        "height_min": float(H.min()), "height_max": float(H.max()),
    }
    placements["meta"] = meta
    with open(os.path.join(OUT, "placements.json"), "w", encoding="utf-8") as f:
        json.dump(placements, f, separators=(",", ":"))

    mk.save_blend(BLEND)
    mk.export_glb(os.path.join(OUT, "terrain.glb"), vertex_colors=True)
    mapgen.write_png(os.path.join(PREV, "map_overview.png"), annotate_preview(g, g.minimap(800), placements))
    log("done in %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
