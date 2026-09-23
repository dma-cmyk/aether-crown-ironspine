# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy"]
# ///
"""Synthesise all game sound effects, ambience loops and the battle theme.

Run: uv run tools/audio/gen_audio.py
Output: game/assets/audio/*.wav (44.1 kHz, 16-bit)
"""
import math
import pathlib
import sys
import wave

import numpy as np

SR = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "game" / "assets" / "audio"
rng = np.random.default_rng(1234)


# ---------------------------------------------------------------- helpers
def secs(n):
    return np.arange(int(n)) / SR


def n_of(sec):
    return int(sec * SR)


def noise(sec):
    return rng.standard_normal(n_of(sec))


def env_exp(sec, tau, attack=0.002):
    t = secs(n_of(sec))
    e = np.exp(-t / tau)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return e * a


def filt(x, lo=None, hi=None, order=2):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    H = np.ones_like(f)
    if hi:
        H /= np.sqrt(1 + (f / hi) ** (2 * order))
    if lo:
        H /= np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(X * H, len(x))


def sweep(f0, f1, sec, shape="exp"):
    n = n_of(sec)
    t = secs(n)
    if shape == "exp":
        f = f0 * (f1 / f0) ** (t / sec)
    else:
        f = f0 + (f1 - f0) * t / sec
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def saw(freq, sec, detune=0.0):
    t = secs(n_of(sec))
    out = np.zeros_like(t)
    for d in (-detune, 0.0, detune) if detune else (0.0,):
        ph = (t * freq * (1 + d)) % 1.0
        out += 2 * ph - 1
    return out / (3 if detune else 1)


def mix_at(dst, src, start_sec, gain=1.0):
    i = n_of(start_sec)
    if i >= len(dst):
        return dst
    j = min(len(dst), i + len(src))
    dst[i:j] += src[: j - i] * gain
    return dst


def reverb(x, sec=1.2, mix=0.25, lo=200, hi=5000):
    ir_n = n_of(sec)
    ir = rng.standard_normal(ir_n) * np.exp(-secs(ir_n) / (sec / 5))
    ir = filt(ir, lo, hi)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    n = len(x) + ir_n
    size = 1 << (n - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]
    out = np.concatenate([x, np.zeros(ir_n)])
    return out * (1 - mix) + wet * mix


def normalize(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade_tail(x, sec=0.02):
    n = min(len(x), n_of(sec))
    x[-n:] *= np.linspace(1, 0, n)
    return x


def write(name, x, peak=0.9, stereo=None):
    OUT.mkdir(parents=True, exist_ok=True)
    if stereo is not None:
        l, r = stereo
        m = max(np.max(np.abs(l)), np.max(np.abs(r))) + 1e-9
        data = np.stack([l / m * peak, r / m * peak], axis=-1)
        ch = 2
    else:
        data = normalize(fade_tail(x.copy()), peak)[:, None]
        ch = 1
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(str(OUT / (name + ".wav")), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", name, "%.2fs" % (len(pcm) / SR))


# ---------------------------------------------------------------- weapons
def crack(sec=0.18, bright=5500, body=150):
    n = n_of(sec)
    c = filt(noise(sec), 700, bright) * env_exp(sec, 0.012)
    thump = np.sin(2 * np.pi * body * secs(n)) * env_exp(sec, 0.03) * 0.6
    tail = filt(noise(sec), 200, 1800) * env_exp(sec, 0.06) * 0.25
    return c + thump + tail


def rifle_volley(seed):
    r = np.random.default_rng(seed)
    out = np.zeros(n_of(0.9))
    for k in range(r.integers(4, 7)):
        mix_at(out, crack(0.2, 5000 + r.uniform(-800, 800), 140 + r.uniform(-30, 30)), r.uniform(0, 0.14), r.uniform(0.6, 1.0))
    return reverb(out, 0.8, 0.18)


def gatling(seed):
    r = np.random.default_rng(seed)
    out = np.zeros(n_of(0.8))
    for k in range(9):
        mix_at(out, crack(0.12, 4200, 110), k * 0.045 + r.uniform(0, 0.006), r.uniform(0.7, 1.0))
    whir = sweep(220, 160, 0.8) * env_exp(0.8, 0.3) * 0.08
    out += whir
    return reverb(out, 0.6, 0.15)


def cannon(seed):
    r = np.random.default_rng(seed)
    sec = 1.8
    boom = sweep(95 + r.uniform(-8, 8), 38, sec) * env_exp(sec, 0.28, 0.004)
    blast = filt(noise(sec), 60, 1400) * env_exp(sec, 0.22, 0.002)
    crk = filt(noise(sec), 1500, 7000) * env_exp(sec, 0.01) * 0.5
    rumble = filt(noise(sec), 30, 250) * env_exp(sec, 0.6) * 0.5
    return reverb(boom * 0.9 + blast * 0.8 + crk + rumble, 1.4, 0.22)


def mortar():
    sec = 1.6
    thump = sweep(70, 32, sec) * env_exp(sec, 0.3, 0.004)
    blast = filt(noise(sec), 40, 900) * env_exp(sec, 0.18)
    whoosh = filt(noise(sec), 400, 2500) * np.exp(-((secs(n_of(sec)) - 0.35) / 0.25) ** 2) * 0.25
    return reverb(thump + blast * 0.8 + whoosh, 1.3, 0.2)


def beam(seed):
    r = np.random.default_rng(seed)
    sec = 0.8
    t = secs(n_of(sec))
    f = 1600 * np.exp(-t * 3.0) + 420 + 60 * np.sin(2 * np.pi * 34 * t)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR)
    shimmer = filt(noise(sec), 3000, 12000) * 0.35
    crackle = (r.random(len(t)) < 0.004) * r.standard_normal(len(t)) * 1.5
    x = (tone * 0.6 + shimmer + filt(crackle, 800, 8000)) * env_exp(sec, 0.22, 0.01)
    return reverb(x, 0.9, 0.3, 400, 9000)


def explosion(sec, size, seed):
    r = np.random.default_rng(seed)
    t = secs(n_of(sec))
    low = filt(noise(sec), 25, 380 * size) * env_exp(sec, 0.35 * size, 0.004)
    mid = filt(noise(sec), 300, 2400) * env_exp(sec, 0.12 * size, 0.002) * 0.6
    crk = filt(noise(sec), 2000, 9000) * env_exp(sec, 0.015) * 0.5
    thump = sweep(80, 30, sec) * env_exp(sec, 0.25 * size) * 0.8
    debris = np.zeros_like(t)
    for k in range(int(30 * size)):
        s = crack(0.05, 6000, 300) * r.uniform(0.05, 0.2)
        mix_at(debris, s, r.uniform(0.15, sec * 0.8))
    return reverb(low + mid + crk + thump + debris, 1.6, 0.25)


# ---------------------------------------------------------------- ui / events
def bell(freq, sec, partials=((1, 1), (2.76, 0.4), (5.4, 0.2), (8.9, 0.1)), tau=0.6):
    t = secs(n_of(sec))
    out = np.zeros_like(t)
    for mult, amp in partials:
        out += amp * np.sin(2 * np.pi * freq * mult * t) * np.exp(-t / (tau / mult ** 0.5))
    return out


def horn(freq, sec, bright=2200, vib=5.0):
    t = secs(n_of(sec))
    f = freq * (1 + 0.006 * np.sin(2 * np.pi * vib * t))
    ph = np.cumsum(f) / SR
    x = sum((1 / k) * np.sin(2 * np.pi * k * ph) for k in range(1, 12))
    a = np.clip(t / 0.06, 0, 1) * np.clip((sec - t) / 0.15, 0, 1)
    return filt(x, 80, bright) * a


def ui_sounds():
    t = secs(n_of(0.05))
    click = np.sin(2 * np.pi * 2100 * t) * np.exp(-t / 0.008) + filt(noise(0.05), 2000, 9000) * np.exp(-t / 0.003) * 0.3
    write("ui_click", click, 0.6)
    c = np.zeros(n_of(0.25))
    mix_at(c, bell(880, 0.2, tau=0.08), 0.0)
    mix_at(c, bell(1320, 0.2, tau=0.08), 0.07)
    write("ui_confirm", c, 0.6)
    t = secs(n_of(0.22))
    err = np.sign(np.sin(2 * np.pi * 150 * t)) * np.clip((0.22 - t) / 0.05, 0, 1)
    write("ui_error", filt(err, 60, 1200), 0.5)
    a = np.zeros(n_of(0.7))
    mix_at(a, bell(659, 0.5, tau=0.25), 0.0)
    mix_at(a, bell(523, 0.5, tau=0.3), 0.18)
    write("ui_alert", reverb(a, 0.8, 0.2), 0.6)
    cap = np.zeros(n_of(1.6))
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
        mix_at(cap, bell(f, 1.2, tau=0.5), i * 0.09, 0.8)
    write("capture", reverb(cap, 1.4, 0.3), 0.7)
    bd = np.zeros(n_of(1.4))
    mix_at(bd, bell(392, 1.2, tau=0.7), 0.0)
    mix_at(bd, bell(587.3, 1.2, tau=0.7), 0.15, 0.7)
    mix_at(bd, filt(noise(0.2), 1500, 7000) * env_exp(0.2, 0.02), 0.0, 0.4)
    write("build_done", reverb(bd, 1.2, 0.25), 0.7)
    ur = np.zeros(n_of(1.0))
    mix_at(ur, horn(392, 0.35), 0.0)
    mix_at(ur, horn(523.25, 0.55), 0.3)
    write("unit_ready", reverb(ur, 1.0, 0.25), 0.6)
    ob = np.zeros(n_of(2.2))
    for i, (f, d) in enumerate(((392, 0.3), (523.25, 0.3), (659.25, 0.3), (783.99, 1.0))):
        mix_at(ob, horn(f, d + 0.1) + horn(f / 2, d + 0.1) * 0.5, i * 0.28)
    write("objective", reverb(ob, 1.6, 0.3), 0.7)
    sp = filt(noise(1.2), 300, 6000) * np.exp(-((secs(n_of(1.2)) - 0.4) / 0.25) ** 2)
    sp += sweep(300, 1800, 1.2) * env_exp(1.2, 0.4, 0.2) * 0.4
    write("special", reverb(sp, 1.0, 0.3), 0.7)
    th = sweep(120, 50, 0.3) * env_exp(0.3, 0.06) + filt(noise(0.3), 80, 900) * env_exp(0.3, 0.04) * 0.5
    write("thud_1", th, 0.5)


# ---------------------------------------------------------------- ambience + music
def loopify(x, xfade_sec=2.0):
    n = n_of(xfade_sec)
    head = x[:n].copy()
    tail = x[-n:].copy()
    ramp = np.linspace(0, 1, n)
    body = x[n:-n].copy() if len(x) > 2 * n else x
    blended = tail * (1 - ramp) + head * ramp
    return np.concatenate([blended, body])


def ambience():
    sec = 24.0
    t = secs(n_of(sec))
    wind = filt(noise(sec), 60, 900) * (0.5 + 0.35 * np.sin(2 * np.pi * t / 7.3) + 0.15 * np.sin(2 * np.pi * t / 2.9))
    gust = filt(noise(sec), 500, 2500) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 11.0)) ** 3 * 0.25
    write("amb_wind", loopify(wind + gust), 0.35)
    battle = np.zeros(n_of(sec))
    r = np.random.default_rng(77)
    for k in range(22):
        e = explosion(2.0, r.uniform(0.6, 1.4), int(r.integers(0, 1000)))
        mix_at(battle, filt(e, 20, 700), r.uniform(0, sec - 2.5), r.uniform(0.2, 0.7))
    for k in range(40):
        v = rifle_volley(int(r.integers(0, 1000)))
        mix_at(battle, filt(v, 100, 1500), r.uniform(0, sec - 1.0), r.uniform(0.05, 0.15))
    write("amb_battle", loopify(battle), 0.4)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def music():
    bpm = 84.0
    beat = 60.0 / bpm
    bars = 16
    sec = bars * 4 * beat
    total = sec + 4.0
    L = np.zeros(n_of(total))
    R = np.zeros(n_of(total))
    # D minor: Dm, Bb, F, C (x4), last pass Gm, Bb, A
    prog = ["Dm", "Bb", "F", "C", "Dm", "Bb", "F", "C", "Dm", "Bb", "F", "C", "Gm", "Bb", "A", "A"]
    chords = {"Dm": (50, 53, 57), "Bb": (46, 50, 53), "F": (41, 45, 48), "C": (48, 52, 55), "Gm": (43, 46, 50), "A": (45, 49, 52)}
    for i, ch in enumerate(prog):
        start = i * 4 * beat
        dur = 4 * beat + 0.6
        pad = np.zeros(n_of(dur))
        for k, m in enumerate(chords[ch]):
            p = saw(midi(m), dur, detune=0.004)
            pad += p * (0.9 if k == 0 else 0.6)
        bass = saw(midi(chords[ch][0] - 12), dur, detune=0.002)
        t = secs(n_of(dur))
        a = np.clip(t / 0.8, 0, 1) * np.clip((dur - t) / 0.6, 0, 1)
        pad = filt(pad, 80, 900) * a * 0.22
        bass = filt(bass, 30, 300) * a * 0.35
        mix_at(L, pad * 1.0 + bass, start)
        mix_at(R, pad * 0.85 + bass, start + 0.012)
    # war drums
    def drum(size):
        d = 0.9
        return sweep(90 * size, 42 * size, d) * env_exp(d, 0.18, 0.003) + filt(noise(d), 40, 400) * env_exp(d, 0.08) * 0.5

    def snare():
        d = 0.35
        return filt(noise(d), 800, 6000) * env_exp(d, 0.06) * 0.5 + np.sin(2 * np.pi * 190 * secs(n_of(d))) * env_exp(d, 0.05) * 0.3

    for bar in range(bars):
        b0 = bar * 4 * beat
        if bar < 2:
            continue
        pattern = [(0.0, 1.0), (1.5, 0.6), (2.0, 0.9), (3.5, 0.5)] if bar % 4 != 3 else [(0.0, 1.0), (1.0, 0.8), (2.0, 0.9), (2.5, 0.7), (3.0, 0.9), (3.5, 1.0)]
        for (bt, g) in pattern:
            d = drum(1.0 if g > 0.7 else 1.3)
            mix_at(L, d, b0 + bt * beat, g * 0.55)
            mix_at(R, d, b0 + bt * beat, g * 0.55)
        if bar >= 4:
            s = snare()
            mix_at(L, s, b0 + 1.0 * beat, 0.25)
            mix_at(R, s, b0 + 3.0 * beat, 0.25)
    # horn melody from bar 4
    melody = [(62, 1.0), (65, 1.0), (69, 2.0), (67, 1.5), (65, 0.5), (64, 2.0), (62, 3.0), (None, 1.0),
              (62, 1.0), (65, 1.0), (69, 1.5), (70, 0.5), (72, 2.0), (69, 1.0), (67, 1.0), (69, 4.0),
              (74, 2.0), (72, 1.0), (70, 1.0), (69, 2.0), (65, 2.0), (67, 1.5), (69, 0.5), (64, 2.0), (61, 4.0)]
    tpos = 4 * 4 * beat
    for m, d in melody:
        if m is not None:
            h = horn(midi(m), d * beat + 0.08, bright=1800, vib=4.5) * 0.3 + horn(midi(m - 12), d * beat + 0.08, bright=900) * 0.18
            mix_at(L, h, tpos, 0.9)
            mix_at(R, h, tpos + 0.008, 1.0)
        tpos += d * beat
    L = reverb(L, 2.2, 0.28)[: n_of(total)]
    R = reverb(R, 2.3, 0.28)[: n_of(total)]
    # wrap the tail into the start so the loop is seamless
    body_n = n_of(sec)
    for ch in (L, R):
        tail = ch[body_n:].copy()
        ch[: len(tail)] += tail
    write("music_battle", None, 0.8, stereo=(L[:body_n], R[:body_n]))


# ---------------------------------------------------------------- creatures
# Each creature sound seeds its own generator, so `gen_audio.py creatures` alone reproduces
# the same files as a full run.
def rnoise(r, sec):
    return r.standard_normal(n_of(sec))


def voice(r, f0, sec, contour, formants, rough=0.35, breath=0.3):
    """Growling voice: jittery sawtooth through vocal-tract band-passes, plus breath noise."""
    t = secs(n_of(sec))
    jitter = filt(r.standard_normal(len(t)), None, 18) * 6.0
    f = f0 * np.interp(t / sec, np.linspace(0, 1, len(contour)), contour) * (1 + 0.012 * jitter)
    ph = np.cumsum(f) / SR
    src = 2 * (ph % 1.0) - 1
    am = 1.0 + rough * np.sin(2 * np.pi * 27 * t + 2 * np.sin(2 * np.pi * 3 * t))
    out = np.zeros_like(t)
    for (fc, bw, g) in formants:
        out += filt(src, fc - bw / 2, fc + bw / 2) * g
    out = out * am + filt(rnoise(r, sec), 250, 3200) * breath
    return out


def creature_sounds():
    r = np.random.default_rng(900)
    sec = 1.7
    env = np.clip(secs(n_of(sec)) / 0.12, 0, 1) * np.clip((sec - secs(n_of(sec))) / 0.6, 0, 1)
    roar = voice(r, 78, sec, [0.8, 1.15, 1.25, 1.1, 0.8], [(420, 300, 1.0), (900, 500, 0.6), (2300, 900, 0.25)], 0.45, 0.45) * env
    write("roar_1", reverb(roar, 1.6, 0.3), 0.8)

    r = np.random.default_rng(901)
    sec = 2.0
    t = secs(n_of(sec))
    env = np.clip(t / 0.08, 0, 1) * np.exp(-t / 0.9)
    groan = voice(r, 95, sec, [1.2, 1.0, 0.7, 0.5], [(380, 260, 1.0), (820, 400, 0.5)], 0.6, 0.35) * env
    write("roar_death_1", reverb(groan, 1.8, 0.3), 0.75)

    for k in range(2):
        r = np.random.default_rng(910 + k)
        sec = 1.6
        thump = sweep(95 + k * 10, 30, sec) * env_exp(sec, 0.22, 0.003)
        crunch = filt(rnoise(r, sec), 200, 3200) * env_exp(sec, 0.06, 0.002) * 0.8
        rumble = filt(rnoise(r, sec), 30, 220) * env_exp(sec, 0.5) * 0.6
        debris = np.zeros(n_of(sec))
        for _ in range(26):
            mix_at(debris, filt(rnoise(r, 0.05), 1500, 6000) * env_exp(0.05, 0.01) * r.uniform(0.05, 0.25), r.uniform(0.08, 1.0))
        write("smash_%d" % (k + 1), reverb(thump + crunch + rumble + debris, 1.3, 0.22), 0.85)

    for k in range(2):
        r = np.random.default_rng(920 + k)
        sec = 0.4
        snap = filt(rnoise(r, sec), 900, 6000) * env_exp(sec, 0.012, 0.001)
        growl = voice(r, 120 + k * 25, sec, [1.0, 1.1, 0.9], [(500, 300, 1.0), (1100, 500, 0.5)], 0.5, 0.3)
        growl *= np.clip(secs(n_of(sec)) / 0.03, 0, 1) * np.exp(-secs(n_of(sec)) / 0.15)
        write("bite_%d" % (k + 1), reverb(snap + growl * 0.6, 0.5, 0.15), 0.6)

    r = np.random.default_rng(930)
    sec = 1.3
    t = secs(n_of(sec))
    flicker = 1.0 + 0.35 * filt(r.standard_normal(len(t)), None, 12) * 4.0
    body = filt(rnoise(r, sec), 140, 2600) * flicker
    rumble = filt(rnoise(r, sec), 35, 180) * 0.8
    crackle = filt((r.random(len(t)) < 0.003) * r.standard_normal(len(t)) * 2.0, 1500, 8000)
    env = np.clip(t / 0.12, 0, 1) * np.clip((sec - t) / 0.4, 0, 1)
    write("flame_1", reverb((body + rumble + crackle) * env, 1.0, 0.2), 0.7)

    r = np.random.default_rng(940)
    sec = 1.6
    thud = sweep(62, 24, sec) * env_exp(sec, 0.35, 0.004)
    dust = filt(rnoise(r, sec), 80, 900) * env_exp(sec, 0.25, 0.01) * 0.7
    write("thud_big_1", reverb(thud + dust, 1.4, 0.2), 0.85)

    r = np.random.default_rng(950)
    sec = 0.9
    t = secs(n_of(sec))
    f = np.interp(t / sec, [0, 0.15, 1], [1700, 2300, 1350]) * (1 + 0.03 * np.sin(2 * np.pi * 23 * t))
    ph = np.cumsum(f) / SR
    cry = np.sin(2 * np.pi * ph) + 0.5 * np.sin(4 * np.pi * ph) + 0.25 * np.sin(6 * np.pi * ph)
    rasp = 1.0 + 0.5 * filt(r.standard_normal(len(t)), 40, 400) * 3.0
    env = np.clip(t / 0.03, 0, 1) * np.clip((sec - t) / 0.35, 0, 1)
    write("screech_1", reverb(cry * rasp * env, 1.2, 0.3, 600, 9000), 0.55)

    r = np.random.default_rng(960)
    sec = 2.0
    t = secs(n_of(sec))
    howl = np.zeros_like(t)
    for k, (f0, d) in enumerate(((310, 0.0), (365, 0.08), (275, 0.15))):
        f = f0 * np.interp(np.clip((t - d) / (sec - d), 0, 1), [0, 0.25, 0.7, 1], [0.85, 1.25, 1.2, 0.9]) * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t + k))
        ph = np.cumsum(f) / SR
        v = np.sin(2 * np.pi * ph) + 0.35 * np.sin(4 * np.pi * ph) + 0.12 * np.sin(6 * np.pi * ph)
        howl += v * np.clip((t - d) / 0.25, 0, 1) * np.clip((sec - t) / 0.5, 0, 1)
    write("howl_1", reverb(filt(howl, 150, 3000), 1.6, 0.35), 0.6)


def main():
    if "creatures" in sys.argv[1:]:
        creature_sounds()
        return
    for i in range(3):
        write("rifle_%d" % (i + 1), rifle_volley(10 + i), 0.55)
    for i in range(2):
        write("gatling_%d" % (i + 1), gatling(20 + i), 0.55)
        write("cannon_%d" % (i + 1), cannon(30 + i), 0.8)
        write("beam_%d" % (i + 1), beam(40 + i), 0.6)
        write("explosion_%d" % (i + 1), explosion(2.2, 1.0, 50 + i), 0.85)
        write("explosion_small_%d" % (i + 1), explosion(1.2, 0.6, 60 + i), 0.7)
    write("mortar_1", mortar(), 0.8)
    write("explosion_big_1", explosion(3.5, 1.6, 70), 0.95)
    ui_sounds()
    ambience()
    music()
    creature_sounds()


if __name__ == "__main__":
    main()
