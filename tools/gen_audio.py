"""Rocky Run audio generator: modern casual-game style (numpy only).

Synthesises every sound from scratch, with no samples or downloads:
  * BGM: a 50-second seamless loop at 116 BPM in C major. Plucked guitar
    chords, a marimba lead, a warm pad with a gentle sidechain pump, a round
    bass, punchy kick, clap, shaker and hats, and room reverb.
  * SFX: soft "boing" jumps, a bell chime for bones, a sparkle arpeggio for
    milestones, a cute yip on a hit, a wood "bonk" on a crash, a gentle
    marimba game over and a puppy bark.

Usage:  python tools/gen_audio.py assets/audio
"""
import os
import sys
import wave

import numpy as np

SR = 32000      # sound effects
SR_BGM = 22050  # music (keeps the web download small)
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(7)


# ---------------------------------------------------------------- helpers
def save(name, sig, sr, peak=0.89):
    sig = np.asarray(sig, dtype=np.float64)
    sig = np.tanh(sig / (np.max(np.abs(sig)) or 1) * 1.15)  # soft limiter
    sig = sig / (np.max(np.abs(sig)) or 1) * peak
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((sig * 32767).astype(np.int16).tobytes())
    print(f"{name:16s} {len(sig) / sr:5.2f}s  {os.path.getsize(os.path.join(OUT, name)) // 1024} KB")


def hz(note):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7,
             "G#": 8, "A": 9, "A#": 10, "B": 11}
    return 440.0 * 2 ** ((12 * (int(note[-1]) + 1) + names[note[:-1]] - 69) / 12)


def fade(x, sr, ms=15):
    """Short fade-out at the end so a note never stops with a click."""
    x = np.array(x, dtype=np.float64)
    n = min(len(x), int(sr * ms / 1000))
    if n > 1:
        x[-n:] *= np.linspace(1, 0, n) ** 2
    return x


def tt(dur, sr):
    return np.arange(int(dur * sr)) / sr


def adsr(n, sr, a=0.005, d=0.1, s=0.6, r=0.1):
    e = np.full(n, s)
    ai, di, ri = int(a * sr), int(d * sr), int(r * sr)
    ai = max(ai, 1)
    e[:ai] = np.linspace(0, 1, ai)
    e[ai:ai + di] = np.linspace(1, s, len(e[ai:ai + di]))
    if ri:
        e[-ri:] *= np.linspace(1, 0, min(ri, n))
    return e


def lowpass(x, sr, cutoff):
    """Smooth low-pass in the frequency domain (fine for offline audio)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    X *= 1 / np.sqrt(1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def highpass(x, sr, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    X *= 1 / np.sqrt(1 + (cutoff / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(X, len(x))


def reverb(x, sr, size=1.4, mix=0.22, tone=5000, seed=1):
    """Convolution reverb with a soft, decaying noise tail."""
    n = int(size * sr)
    t = np.arange(n) / sr
    ir = np.random.default_rng(seed).standard_normal(n) * np.exp(-t * 6.5 / size)
    ir = lowpass(ir, sr, tone)
    ir[: int(0.012 * sr)] = 0  # pre-delay
    ir /= np.sqrt(np.sum(ir ** 2))
    L = len(x) + n
    wet = np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(ir, L), L)
    out = np.zeros(L)
    out[: len(x)] += x * (1 - mix)
    out += wet * mix * 1.6
    return out


# ---------------------------------------------------------------- instruments
def marimba(f, dur, sr, bright=1.0):
    t = tt(dur, sr)
    sig = (np.sin(2 * np.pi * f * t) * np.exp(-t * 5.5)
           + 0.35 * bright * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t * 18)
           + 0.12 * bright * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t * 40))
    return fade(sig * np.minimum(1, t / 0.002), sr, 30)


def bell(f, dur, sr):
    """Soft FM bell / glockenspiel."""
    t = tt(dur, sr)
    mod = np.sin(2 * np.pi * f * 3.5 * t) * 2.2 * np.exp(-t * 6)
    car = np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 3.2)
    car += 0.25 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 6)
    return fade(car * np.minimum(1, t / 0.002), sr, 40)


def pluck(f, dur, sr, damp=0.996, bright=0.55):
    """Karplus-Strong plucked string (nylon guitar / ukulele feel)."""
    n = int(dur * sr)
    p = max(2, int(sr / f))
    buf = RNG.uniform(-1, 1, p)
    buf = lowpass(np.concatenate([buf, buf]), sr, f * 8 * bright)[:p]
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = damp * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    return fade(out, sr, 40)


def pad(freqs, dur, sr):
    t = tt(dur, sr)
    sig = np.zeros_like(t)
    for f in freqs:
        for det in (-0.12, 0.0, 0.12):  # detuned voices
            ph = 2 * np.pi * f * 2 ** (det / 12) * t + RNG.uniform(0, 6.28)
            sig += np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    return sig * adsr(len(t), sr, a=0.35, d=0.4, s=0.75, r=0.5)


def bass(f, dur, sr):
    t = tt(dur, sr)
    sig = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)
    return np.tanh(sig * 1.4) * adsr(len(t), sr, a=0.004, d=0.12, s=0.7, r=0.06)


def kick(sr):
    t = tt(0.32, sr)
    f = 48 + 120 * np.exp(-t * 28)
    body = np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t * 9)
    click = RNG.standard_normal(len(t)) * np.exp(-t * 400) * 0.25
    return np.tanh((body + click) * 1.5)


def clap(sr):
    t = tt(0.3, sr)
    n = highpass(RNG.standard_normal(len(t)), sr, 900)
    env = np.zeros_like(t)
    for k, off in enumerate((0, 0.009, 0.018)):  # three quick hand hits
        i = int(off * sr)
        env[i:] += np.exp(-(t[: len(t) - i]) * (60 if k < 2 else 14)) * (0.7 if k < 2 else 1)
    return lowpass(n * env, sr, 7000) * 0.9


def hat(sr, open_=False):
    t = tt(0.25 if open_ else 0.06, sr)
    n = highpass(RNG.standard_normal(len(t)), sr, 7000)
    return n * np.exp(-t * (14 if open_ else 70)) * 0.5


def shaker(sr):
    t = tt(0.09, sr)
    n = highpass(RNG.standard_normal(len(t)), sr, 5000)
    return n * np.sin(np.pi * np.minimum(1, t / 0.09)) ** 2 * 0.28


# ---------------------------------------------------------------- SFX
def sfx_jump():
    t = tt(0.22, SR)
    f = 330 + 520 * (1 - np.exp(-t * 22))          # quick upward "boing"
    tone = fade(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11), SR, 40)
    whoosh = highpass(RNG.standard_normal(len(t)), SR, 2500) * np.exp(-t * 25) * 0.12
    return reverb(tone + whoosh, SR, 0.5, 0.12)


def sfx_double_jump():
    t = tt(0.3, SR)
    f = 620 + 900 * (1 - np.exp(-t * 26))
    tone = fade(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 10), SR, 40)
    spark = sum(bell(hz(n), 0.3, SR) * 0.25 for n in ("E6", "B6"))
    return reverb(tone + spark, SR, 0.6, 0.18)


def sfx_bone():
    a = bell(hz("E6"), 0.6, SR)
    b = np.concatenate([np.zeros(int(0.07 * SR)), bell(hz("B6"), 0.53, SR)])
    sparkle = highpass(RNG.standard_normal(len(a)), SR, 8000) * np.exp(-tt(0.6, SR) * 12) * 0.05
    return reverb(a * 0.8 + b + sparkle, SR, 0.9, 0.22)


def sfx_milestone():
    out = np.zeros(int(1.3 * SR))
    for i, n in enumerate(("C6", "E6", "G6", "C7", "E7")):
        s = bell(hz(n), 0.9, SR) * (0.7 + 0.08 * i)
        j = int(i * 0.075 * SR)
        out[j:j + len(s)] += s[: len(out) - j]
    return reverb(out, SR, 1.2, 0.25)


def sfx_hurt():
    t = tt(0.17, SR)
    f = 1500 * np.exp(-t * 7) + 650                 # cute "yip"
    ph = np.cumsum(f) / SR
    voice = fade((np.sin(2 * np.pi * ph) + 0.45 * np.sin(4 * np.pi * ph)) * np.minimum(1, t / 0.006) * np.exp(-t * 14), SR, 30)
    thud_t = tt(0.18, SR)
    thud = fade(np.sin(2 * np.pi * np.cumsum(140 * np.exp(-thud_t * 10) + 60) / SR) * np.exp(-thud_t * 18) * 0.6, SR, 30)
    sig = np.zeros(int(0.35 * SR))
    sig[: len(voice)] += voice
    sig[: len(thud)] += thud
    return reverb(sig, SR, 0.5, 0.12)


def sfx_hit():
    t = tt(0.45, SR)
    wood = (np.sin(2 * np.pi * 820 * t) * np.exp(-t * 38)
            + 0.5 * np.sin(2 * np.pi * 1640 * t) * np.exp(-t * 60))   # cartoon "bonk"
    thud = np.sin(2 * np.pi * np.cumsum(90 + 140 * np.exp(-t * 20)) / SR) * np.exp(-t * 8)
    dust = lowpass(RNG.standard_normal(len(t)), SR, 1800) * np.exp(-t * 9) * 0.25
    return reverb(fade(wood * 0.7 + thud + dust, SR, 40), SR, 0.7, 0.15)


def sfx_game_over():
    out = np.zeros(int(2.0 * SR))
    for i, n in enumerate(("G5", "E5", "C5", "D5", "C5")):
        d = 0.9 if i == 4 else 0.5
        s = marimba(hz(n), d, SR) * (1.0 if i < 4 else 1.15)
        j = int((0.16 * i + (0.1 if i == 4 else 0)) * SR)
        out[j:j + len(s)] += s[: len(out) - j]
    out += np.concatenate([np.zeros(int(0.74 * SR)), pad([hz("C4"), hz("E4"), hz("G4")], 1.26, SR) * 0.06])
    return reverb(out, SR, 1.4, 0.25)


def sfx_bark():
    def one(d, f0, seed):
        t = tt(d, SR)
        f = f0 * (1 + 0.35 * np.exp(-t * 30)) * (1 - 0.25 * t / d)
        ph = np.cumsum(f) / SR
        src = sum(np.sin(2 * np.pi * k * ph) / k for k in range(1, 12))
        noise = np.random.default_rng(seed).standard_normal(len(t)) * 0.25
        # formant-ish shaping: puppy "arf"
        voiced = lowpass(src + noise, SR, 2400) + 0.5 * highpass(lowpass(src, SR, 3200), SR, 1400)
        return fade(voiced * np.minimum(1, t / 0.008) * np.exp(-t * 16), SR, 25)
    a = one(0.15, 520, 1)
    b = one(0.12, 600, 2) * 0.8
    sig = np.concatenate([a, np.zeros(int(0.05 * SR)), b])
    return reverb(sig, SR, 0.5, 0.1)


# ---------------------------------------------------------------- BGM
def bgm():
    sr = SR_BGM
    bpm = 116
    beat = 60 / bpm
    bars = 24
    total = int(round(bars * 4 * beat * sr))
    tail = int(2.0 * sr)
    mix = {k: np.zeros(total + tail) for k in ("drums", "bass", "keys", "lead", "pad")}

    def put(track, s, at, g=1.0):
        i = int(round(at * sr))
        s = fade(s, sr, 12)
        n = min(len(s), len(mix[track]) - i)
        mix[track][i:i + n] += s[:n] * g

    chords = {  # C - G - Am - F (bright, feel-good)
        "C": ["C4", "E4", "G4"], "G": ["B3", "D4", "G4"],
        "Am": ["A3", "C4", "E4"], "F": ["A3", "C4", "F4"],
    }
    roots = {"C": "C2", "G": "G2", "Am": "A2", "F": "F2"}
    prog = ["C", "G", "Am", "F"]
    # marimba melody: 8 eighth notes per bar ('-' rest, '.' hold)
    mel_a = ["E5 . G5 . C6 . G5 .", "D5 . G5 . B5 . A5 G5", "C5 . E5 . A5 . G5 E5", "F5 . E5 . D5 . C5 ."]
    mel_b = ["G5 E5 C5 E5 G5 . C6 .", "B5 . A5 . G5 . D5 .", "A5 G5 E5 . C5 . E5 G5", "A5 . G5 . F5 E5 D5 ."]

    for bar in range(bars):
        t0 = bar * 4 * beat
        ch = prog[bar % 4]
        section = bar // 8  # 0 intro, 1 main, 2 main + counter melody
        # plucked guitar chord pattern (on 1, &2, 3, &4)
        for k, off in enumerate((0, 1.5, 2, 3.5)):
            for j, n in enumerate(chords[ch]):
                put("keys", pluck(hz(n), 0.9, sr), t0 + off * beat + j * 0.012, 0.22 if k % 2 == 0 else 0.15)
        # pad from the main section on
        put("pad", pad([hz(n) for n in chords[ch]], 4 * beat + 0.4, sr), t0,
            0.05 if section >= 1 else 0.04)
        # bass: root on 1 and 3, a pickup on &4
        if True:
            r = hz(roots[ch])
            put("bass", bass(r, beat * 0.9, sr), t0, 0.5)
            put("bass", bass(r, beat * 0.9, sr), t0 + 2 * beat, 0.45)
            put("bass", bass(r * 2, beat * 0.4, sr), t0 + 3.5 * beat, 0.3)
        # drums
        for b in range(4):
            tb = t0 + b * beat
            if section >= 1 or bar >= 4:
                if b in (0, 2) or (b == 3 and bar % 2):
                    put("drums", kick(sr), tb + (0.5 * beat if b == 3 else 0), 0.8)
                if b in (1, 3):
                    put("drums", clap(sr), tb, 0.45)
            for h in range(2):  # shaker 8ths throughout, hats from main
                put("drums", shaker(sr), tb + h * beat / 2, 0.6 if h else 0.35)
                if section >= 1:
                    put("drums", hat(sr, open_=(h == 1 and b == 3)), tb + h * beat / 2, 0.35)
        # melodies
        if section >= 1:
            tok = (mel_a if section == 1 else mel_b)[bar % 4].split()
            i = 0
            while i < 8:
                if tok[i] in "-.":
                    i += 1
                    continue
                ln = 1
                while i + ln < 8 and tok[i + ln] == ".":
                    ln += 1
                put("lead", marimba(hz(tok[i]), ln * beat / 2 + 0.4, sr), t0 + i * beat / 2, 0.42)
                if section == 2:  # bell doubling an octave up, very soft
                    put("lead", bell(hz(tok[i]) * 2, 0.5, sr), t0 + i * beat / 2, 0.06)
                i += ln

    # sidechain pump on keys + pad (follows the kick on every beat)
    t = np.arange(total + tail) / sr
    pump = 1 - 0.35 * np.exp(-(t % beat) * 9)
    mix["pad"] *= pump
    mix["keys"] *= 0.85 + 0.15 * pump

    dry = (mix["drums"] * 0.9 + mix["bass"] * 0.9 + mix["keys"] + mix["lead"] + mix["pad"])
    wet_src = mix["keys"] + mix["lead"] * 1.2 + mix["pad"] + mix["drums"] * 0.15
    wet = reverb(wet_src, sr, 1.6, 1.0, tone=4500)[: len(dry)] * 0.18
    song = lowpass(dry + wet, sr, 9500)
    # seamless loop: fold the tail (reverb / ringing notes) onto the start
    loop = song[:total].copy()
    loop[:tail] += song[total:total + tail]
    return loop, sr


if __name__ == "__main__":
    for name, fn in [("jump", sfx_jump), ("double_jump", sfx_double_jump), ("bone", sfx_bone),
                     ("milestone", sfx_milestone), ("hurt", sfx_hurt), ("hit", sfx_hit),
                     ("game_over", sfx_game_over), ("bark", sfx_bark)]:
        save(f"{name}.wav", fn(), SR)
    music, sr = bgm()
    save("bgm.wav", music, sr, peak=0.82)
