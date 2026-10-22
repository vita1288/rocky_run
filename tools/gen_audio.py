"""Procedurally generates chiptune SFX + looping BGM for Rocky Run (22.05 kHz, 16-bit mono WAV)."""
import numpy as np, wave, os, sys

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else "rocky_run/assets/audio"
os.makedirs(OUT, exist_ok=True)


def save(name, sig, peak=0.9):
    sig = np.asarray(sig, dtype=np.float64)
    m = np.max(np.abs(sig)) or 1.0
    sig = sig / m * peak
    data = (sig * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}: {len(sig)/SR:.2f}s")


def t_of(dur):
    return np.arange(int(SR * dur)) / SR


def square(freq, dur, duty=0.5):
    t = t_of(dur)
    f = np.broadcast_to(freq, t.shape) if np.ndim(freq) else np.full(t.shape, freq)
    phase = np.cumsum(f) / SR
    return np.where((phase % 1.0) < duty, 1.0, -1.0)


def triangle(freq, dur):
    t = t_of(dur)
    phase = (freq * t) % 1.0
    return 4 * np.abs(phase - 0.5) - 1


def noise(dur, seed=0):
    return np.random.default_rng(seed).uniform(-1, 1, int(SR * dur))


def env(n, a=0.005, r=0.05, sustain=1.0):
    e = np.ones(n) * sustain
    ai = max(1, int(a * SR)); ri = max(1, int(r * SR))
    e[:ai] = np.linspace(0, sustain, ai)
    e[-ri:] *= np.linspace(1, 0, ri)
    return e


def sweep(f0, f1, dur, duty=0.5, curve=1.0):
    n = int(SR * dur)
    f = f0 + (f1 - f0) * np.linspace(0, 1, n) ** curve
    return square(f, dur, duty)


def note_hz(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


# ---------------- SFX ----------------
def sfx_jump():
    s = sweep(260, 760, 0.14, duty=0.25, curve=0.6)
    return s * env(len(s), 0.002, 0.06)


def sfx_double_jump():
    a = sweep(480, 1150, 0.10, duty=0.25, curve=0.5)
    b = sweep(900, 1500, 0.08, duty=0.125)
    s = np.concatenate([a, b * 0.7])
    return s * env(len(s), 0.002, 0.05)


def sfx_bone():
    a = square(note_hz("B5"), 0.06, 0.5) * env(int(SR * 0.06), 0.001, 0.01)
    b = square(note_hz("E6"), 0.22, 0.5) * env(int(SR * 0.22), 0.001, 0.18)
    return np.concatenate([a, b])


def sfx_milestone():
    parts = []
    for nm in ["C6", "E6", "G6", "C7"]:
        d = 0.07
        parts.append(square(note_hz(nm), d, 0.25) * env(int(SR * d), 0.001, 0.02))
    last = square(note_hz("C7"), 0.25, 0.25) * env(int(SR * 0.25), 0.001, 0.22) * 0.8
    return np.concatenate(parts + [last])


def sfx_hit():
    d = 0.35
    n = noise(d, 3) * np.linspace(1, 0, int(SR * d)) ** 2
    tone = sweep(420, 70, d, duty=0.5, curve=0.7) * env(int(SR * d), 0.001, 0.15)
    return 0.6 * n + 0.6 * tone


def sfx_game_over():
    parts = []
    for nm, d in [("G4", 0.16), ("E4", 0.16), ("C4", 0.16), ("G3", 0.5)]:
        parts.append(square(note_hz(nm), d, 0.5) * env(int(SR * d), 0.002, d * 0.6))
    return np.concatenate(parts)


def sfx_bark():
    """Little toy-poodle 'arf!' used on start."""
    d = 0.16
    t = t_of(d)
    f = 820 * np.exp(-t * 6) + 380
    phase = np.cumsum(f) / SR
    voiced = np.sin(2 * np.pi * phase) + 0.5 * np.sin(4 * np.pi * phase) + 0.25 * np.sin(6 * np.pi * phase)
    s = voiced * 0.8 + noise(d, 9) * 0.25
    e = np.minimum(1, t / 0.008) * np.exp(-t * 14)
    return np.concatenate([s * e, np.zeros(int(SR * 0.04)), (s * e)[: int(SR * 0.12)] * 0.8])


save("jump.wav", sfx_jump())
save("double_jump.wav", sfx_double_jump())
save("bone.wav", sfx_bone())
save("milestone.wav", sfx_milestone())
save("hit.wav", sfx_hit())
save("game_over.wav", sfx_game_over())
save("bark.wav", sfx_bark())


def sfx_hurt():
    """Lost a heart: short 'yip' + quick down-sweep (softer than the game-over hit)."""
    d = 0.11
    t = t_of(d)
    f = 1300 * np.exp(-t * 9) + 600
    phase = np.cumsum(f) / SR
    yip = (np.sin(2 * np.pi * phase) + 0.4 * np.sin(4 * np.pi * phase)) * np.minimum(1, t / 0.005) * np.exp(-t * 16)
    down = sweep(700, 260, 0.16, duty=0.25, curve=0.8) * env(int(SR * 0.16), 0.002, 0.08) * 0.5
    return np.concatenate([yip, down])


save("hurt.wav", sfx_hurt())

# ---------------- BGM ----------------
BPM = 150
BEAT = 60 / BPM
EIGHTH = BEAT / 2
BARS = 16
TOTAL = int(round(SR * BEAT * 4 * BARS))
mix = np.zeros(TOTAL + SR)  # padding, trimmed later


def place(sig, start_s, gain=1.0):
    i = int(round(start_s * SR))
    mix[i:i + len(sig)] += sig * gain


# chord progression per bar (roots for bass), C - Am - F - G
prog = ["C", "A", "F", "G"]
bass_oct = {"C": "C2", "A": "A1", "F": "F1", "G": "G1"}
bass_up = {"C": "C3", "A": "A2", "F": "F2", "G": "G2"}

# melody: 8 eighth-notes per bar, '-' = rest, '.' = hold previous
melA = [
    "E5 G5 C6 G5 E5 G5 D5 E5",
    "C5 E5 A5 E5 C5 E5 B4 C5",
    "A4 C5 F5 C5 A4 C5 G4 A4",
    "B4 D5 G5 . F5 . D5 B4",
]
melB = [
    "G5 . E5 G5 C6 . B5 A5",
    "A5 . E5 . C5 D5 E5 .",
    "F5 . A5 . C6 . A5 F5",
    "G5 F5 E5 D5 B4 . G4 -",
]
melody_bars = melA + melB + melA + [melB[0], melB[1], melB[2], "D5 E5 F5 D5 C5 . . -"]

for bar in range(BARS):
    bar_t = bar * BEAT * 4
    root = prog[bar % 4]
    # bass: octave-bouncing eighths (triangle)
    for i in range(8):
        nm = bass_oct[root] if i % 2 == 0 else bass_up[root]
        d = EIGHTH * 0.9
        place(triangle(note_hz(nm), d) * env(int(SR * d), 0.003, 0.03), bar_t + i * EIGHTH, 0.55)
    # lead melody (pulse 25%)
    tokens = melody_bars[bar].split()
    i = 0
    while i < 8:
        tok = tokens[i]
        if tok in ("-", "."):
            i += 1; continue
        length = 1
        while i + length < 8 and tokens[i + length] == ".":
            length += 1
        d = EIGHTH * length * 0.92
        n = int(SR * d)
        tt = np.arange(n) / SR
        vib = 1 + 0.004 * np.sin(2 * np.pi * 6 * tt) * (tt > 0.12)
        sig = square(note_hz(tok) * vib, d, 0.25) * env(n, 0.004, 0.04, 1.0) * (0.75 + 0.25 * np.exp(-tt * 8))
        place(sig, bar_t + i * EIGHTH, 0.22)
        i += length
    # arpeggio harmony (soft 12.5% pulse, 16ths) on second half of the song
    if bar >= 8:
        chord = {"C": ["C4", "E4", "G4", "C5"], "A": ["A3", "C4", "E4", "A4"], "F": ["F3", "A3", "C4", "F4"], "G": ["G3", "B3", "D4", "G4"]}[root]
        for k in range(16):
            d = EIGHTH / 2 * 0.8
            place(square(note_hz(chord[k % 4]), d, 0.125) * env(int(SR * d), 0.002, 0.03), bar_t + k * EIGHTH / 2, 0.07)
    # drums
    for beat in range(4):
        bt = bar_t + beat * BEAT
        if beat in (0, 2):  # kick
            d = 0.14; tt = t_of(d)
            kick = np.sin(2 * np.pi * np.cumsum(55 + 110 * np.exp(-tt * 35)) / SR) * np.exp(-tt * 18)
            place(kick, bt, 0.7)
        if beat in (1, 3):  # snare
            d = 0.12; tt = t_of(d)
            place(noise(d, bar * 4 + beat) * np.exp(-tt * 28), bt, 0.28)
        for h in range(2):  # hats on eighths
            d = 0.035; tt = t_of(d)
            hat = np.diff(noise(d + 1 / SR, 100 + bar * 8 + beat * 2 + h)) * np.exp(-tt * 90)
            place(hat, bt + h * EIGHTH, 0.10)

# fold the tail past the loop point back to the start for a seamless loop
tail = mix[TOTAL:]
mix = mix[:TOTAL].copy()
mix[: len(tail)] += tail
save("bgm.wav", mix, peak=0.8)
