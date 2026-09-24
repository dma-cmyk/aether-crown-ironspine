# /// script
# dependencies = ["playwright"]
# ///
"""Drive the local Web build in a throwaway Chrome profile: console log, screenshots, frame rate.

Serve the build first (tools/export_web.sh && python3 -m http.server -d build/web 8060), then
  uv run tools/web/browser_check.py [--phone] [--out DIR] [--url URL] [--size WxH] '[steps]'
--phone emulates a touch phone (844x390 CSS px, device pixel ratio 3). Steps is a JSON list:
  ["wait", s]  ["shot", name]  ["fps", label, s]  ["js", expr]  ["key", key]
  ["click", x, y]  ["rclick", x, y]           mouse, CSS px
  ["tap", x, y]  ["swipe", x0, y0, x1, y1]    one finger
  ["pinch", cx, cy, d0, d1]                   two fingers, horizontal, spread d0 -> d1 px
  ["until", "console text", s]                wait for a console line containing the text
"""
import argparse, json, pathlib, tempfile, time
from playwright.sync_api import sync_playwright

ap = argparse.ArgumentParser()
ap.add_argument("steps", nargs="?", default="[]")
ap.add_argument("--url", default="http://127.0.0.1:8060/index.html")
ap.add_argument("--size", default="")
ap.add_argument("--phone", action="store_true")
ap.add_argument("--out", default=tempfile.gettempdir())
a = ap.parse_args()
OUT = pathlib.Path(a.out)
OUT.mkdir(parents=True, exist_ok=True)
W, H = map(int, (a.size or ("844x390" if a.phone else "1600x900")).split("x"))
STEPS = json.loads(a.steps)

FPS_JS = """async (ms) => {
  let n = 0, t0 = performance.now(), worst = 0, last = t0;
  await new Promise(res => { function f(t) { n++; worst = Math.max(worst, t - last); last = t; if (t - t0 < ms) requestAnimationFrame(f); else res(); } requestAnimationFrame(f); });
  return {fps: n * 1000 / (performance.now() - t0), worst_ms: worst};
}"""

with sync_playwright() as p:
    prof = tempfile.mkdtemp(prefix="ac-chrome-")
    extra = {"has_touch": True, "is_mobile": True, "device_scale_factor": 3} if a.phone else {}
    ctx = p.chromium.launch_persistent_context(prof, executable_path="/usr/bin/google-chrome-stable", headless=False,
        viewport={"width": W, "height": H}, args=["--no-first-run", "--no-default-browser-check", "--ignore-gpu-blocklist", "--enable-gpu-rasterization"],
        **extra)
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    cdp = ctx.new_cdp_session(page)
    logs = []
    page.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
    page.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))

    def touch(kind, points):
        cdp.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": [{"x": x, "y": y, "id": i} for i, (x, y) in enumerate(points)]})

    def slide(a0, a1, steps=12):
        touch("touchStart", a0)
        for k in range(1, steps + 1):
            t = k / steps
            touch("touchMove", [(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t) for (x0, y0), (x1, y1) in zip(a0, a1)])
            page.wait_for_timeout(16)
        touch("touchEnd", [])

    t0 = time.time()
    page.goto(a.url)
    page.wait_for_function("() => !document.getElementById('status') || getComputedStyle(document.getElementById('status')).visibility === 'hidden' || document.getElementById('status').style.display === 'none'", timeout=180000)
    print(f"engine started after {time.time() - t0:.1f}s", flush=True)
    gl = page.evaluate("""() => { const c = document.createElement('canvas').getContext('webgl2'); if (!c) return 'no webgl2';
        const d = c.getExtension('WEBGL_debug_renderer_info'); return d ? c.getParameter(d.UNMASKED_RENDERER_WEBGL) : 'unknown'; }""")
    print("webgl2 renderer:", gl, flush=True)
    for step in STEPS:
        kind = step[0]
        if kind == "wait":
            page.wait_for_timeout(int(step[1] * 1000))
        elif kind == "shot":
            page.screenshot(path=str(OUT / step[1]))
            print("shot", OUT / step[1], flush=True)
        elif kind == "click":
            page.mouse.click(step[1], step[2])
        elif kind == "rclick":
            page.mouse.click(step[1], step[2], button="right")
        elif kind == "key":
            page.keyboard.press(step[1])
        elif kind == "tap":
            touch("touchStart", [(step[1], step[2])])
            page.wait_for_timeout(60)
            touch("touchEnd", [])
        elif kind == "swipe":
            slide([(step[1], step[2])], [(step[3], step[4])])
        elif kind == "pinch":
            cx, cy, d0, d1 = step[1:5]
            slide([(cx - d0 / 2, cy), (cx + d0 / 2, cy)], [(cx - d1 / 2, cy), (cx + d1 / 2, cy)])
        elif kind == "until":
            end = time.time() + step[2]
            while time.time() < end and not any(step[1] in l for l in logs):
                page.wait_for_timeout(250)
            print("until", step[1], "found" if any(step[1] in l for l in logs) else "TIMED OUT", flush=True)
        elif kind == "fps":
            print("fps", step[1], page.evaluate(FPS_JS, int(step[2] * 1000)), flush=True)
        elif kind == "js":
            print("js", page.evaluate(step[1]), flush=True)
    (OUT / "console.log").write_text("\n".join(logs))
    print(f"{len(logs)} console lines; errors:", sum(1 for l in logs if l.startswith(('[error]', '[pageerror]'))), flush=True)
    ctx.close()
