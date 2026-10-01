#!/usr/bin/env python3
"""Generate every sound in app/sounds/ from scratch: a tiny chiptune synth.

Square and triangle voices plus a noise drum, mixed to 16-bit mono WAV. No
samples, no dependencies, so the audio is ours and reproducible:

    python3 tools/make-sounds.py

The theme is an original boom-chick western shuffle in G; nothing here is
lifted from an existing song.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "app", "sounds")
random.seed(1984)

NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def freq(name):
    """'A4' -> 440.0; None/'-' -> rest."""
    if not name or name == "-":
        return 0.0
    pitch, octave = name[:-1], int(name[-1])
    n = NOTE_INDEX[pitch] + (octave + 1) * 12
    return 440.0 * 2 ** ((n - 69) / 12)


def blank(seconds):
    return [0.0] * int(seconds * RATE)


def mix_into(buf, samples, start, gain=1.0):
    i0 = int(start * RATE)
    need = i0 + len(samples)
    if need > len(buf):
        buf.extend([0.0] * (need - len(buf)))
    for i, s in enumerate(samples):
        buf[i0 + i] += s * gain


def env(n, attack=0.005, decay=0.08, sustain=0.6, release=0.05):
    a, d, r = int(attack * RATE), int(decay * RATE), int(release * RATE)
    out = []
    for i in range(n):
        if i < a:
            v = i / max(1, a)
        elif i < a + d:
            v = 1 - (1 - sustain) * (i - a) / max(1, d)
        else:
            v = sustain
        if i > n - r:
            v *= max(0.0, (n - i) / max(1, r))
        out.append(v)
    return out


def tone(f, seconds, wave_kind="square", duty=0.5, vibrato=0.0, slide=0.0, **kw):
    n = int(seconds * RATE)
    e = env(n, **kw)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        ff = f * (1 + slide * t / max(seconds, 1e-6)) * (1 + vibrato * math.sin(2 * math.pi * 5.5 * t))
        phase = (phase + ff / RATE) % 1.0
        if f == 0:
            s = 0.0
        elif wave_kind == "square":
            s = 1.0 if phase < duty else -1.0
        elif wave_kind == "triangle":
            s = 4 * abs(phase - 0.5) - 1
        else:
            s = math.sin(2 * math.pi * phase)
        out.append(s * e[i])
    return out


def noise(seconds, decay=0.05, tone_hz=0.0, hold=1):
    n = int(seconds * RATE)
    out = []
    v = 0.0
    for i in range(n):
        if i % hold == 0:
            v = random.uniform(-1, 1)
        amp = math.exp(-i / (decay * RATE))
        s = v
        if tone_hz:
            s = 0.6 * v + 0.4 * math.sin(2 * math.pi * tone_hz * i / RATE * math.exp(-i / (0.03 * RATE)))
        out.append(s * amp)
    return out


def write(name, buf, gain=0.32):
    peak = max(1e-6, max(abs(x) for x in buf))
    scale = min(gain / peak * 1.0, gain * 3)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * scale)) * 32767)) for x in buf))
    print(f"{name}: {len(buf) / RATE:.2f}s")


def sequence(buf, notes, start, beat, wave_kind="square", duty=0.5, gain=1.0, gap=0.92, **kw):
    """notes: list of (note, beats). Returns end time."""
    t = start
    for note, beats in notes:
        if note and note != "-":
            mix_into(buf, tone(freq(note), beat * beats * gap, wave_kind, duty, **kw), t, gain)
        t += beat * beats
    return t


# ------------------------------------------------------------------ music --

CHORDS = {
    "G": ("G2", "D3", ["G3", "B3", "D4"]),
    "C": ("C3", "G2", ["C4", "E4", "G4"]),
    "D": ("D3", "A2", ["D4", "F#4", "A4"]),
    "Em": ("E2", "B2", ["E4", "G4", "B4"]),
    "D7": ("D3", "A2", ["C4", "F#4", "A4"]),
}


def boom_chick(buf, progression, start, beat, bass_gain=0.55, chick_gain=0.12):
    """Two beats per bar half: bass root / chord stab / alt bass / stab."""
    t = start
    for chord in progression:
        root, alt, stab = CHORDS[chord]
        mix_into(buf, tone(freq(root), beat * 0.9, "triangle", decay=0.1, sustain=0.7), t, bass_gain)
        for n in stab:
            mix_into(buf, tone(freq(n), beat * 0.35, "square", 0.25, decay=0.05, sustain=0.3), t + beat, chick_gain)
        mix_into(buf, tone(freq(alt), beat * 0.9, "triangle", decay=0.1, sustain=0.7), t + beat * 2, bass_gain)
        for n in stab:
            mix_into(buf, tone(freq(n), beat * 0.35, "square", 0.25, decay=0.05, sustain=0.3), t + beat * 3, chick_gain)
        # snare-ish brush on the offbeats, kick on 1
        mix_into(buf, noise(0.06, 0.02, tone_hz=110), t, 0.35)
        mix_into(buf, noise(0.08, 0.03, hold=2), t + beat, 0.12)
        mix_into(buf, noise(0.08, 0.03, hold=2), t + beat * 3, 0.12)
        t += beat * 4
    return t


def theme():
    beat = 60 / 150
    buf = blank(0)
    prog = ["G", "G", "C", "G", "G", "D", "D7", "G",
            "C", "C", "G", "Em", "C", "D", "D7", "G"]
    boom_chick(buf, prog, 0, beat)
    melody = [
        # A: the hook
        ("D4", 1), ("G4", 1), ("G4", 0.5), ("A4", 0.5), ("B4", 1),
        ("D5", 1.5), ("B4", 0.5), ("G4", 2),
        ("E4", 1), ("G4", 1), ("C5", 1), ("B4", 1),
        ("A4", 1), ("G4", 1), ("B4", 2),
        ("D4", 1), ("G4", 1), ("G4", 0.5), ("A4", 0.5), ("B4", 1),
        ("D5", 1.5), ("E5", 0.5), ("D5", 1), ("B4", 1),
        ("A4", 1), ("F#4", 1), ("A4", 1), ("C5", 1),
        ("B4", 1), ("A4", 0.5), ("F#4", 0.5), ("G4", 2),
        # B: the yee-haw bridge
        ("E5", 1), ("E5", 0.5), ("D5", 0.5), ("C5", 1), ("E5", 1),
        ("G5", 2), ("E5", 1), ("C5", 1),
        ("D5", 1), ("D5", 0.5), ("C5", 0.5), ("B4", 1), ("D5", 1),
        ("G5", 1), ("F#5", 0.5), ("E5", 0.5), ("D5", 1), ("B4", 1),
        ("C5", 1), ("E5", 1), ("G5", 1), ("E5", 1),
        ("D5", 1), ("B4", 1), ("G4", 1), ("B4", 1),
        ("A4", 1), ("D5", 1), ("F#4", 1), ("A4", 1),
        ("G4", 2), ("D4", 1), ("G4", 1),
    ]
    sequence(buf, melody, 0, beat, "square", 0.25, gain=0.42, vibrato=0.004, decay=0.06, sustain=0.55)
    # a harmony a third below in the bridge, quieter, for that two-fiddle feel
    harmony = [(n, b) for n, b in melody[32:]]
    shifted = []
    for n, b in harmony:
        idx = NOTE_INDEX[n[:-1]] + int(n[-1]) * 12 - 4
        names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        shifted.append((names[idx % 12] + str(idx // 12), b))
    sequence(buf, shifted, beat * 32, beat, "square", 0.125, gain=0.14, decay=0.06, sustain=0.5)
    write("theme.wav", buf[: int(beat * 64 * RATE)], gain=0.3)


def travel():
    beat = 60 / 132
    buf = blank(0)
    prog = ["G", "C", "G", "D", "G", "C", "D7", "G"]
    boom_chick(buf, prog, 0, beat, bass_gain=0.5, chick_gain=0.08)
    lick = [("-", 2), ("B4", 0.5), ("D5", 0.5), ("E5", 1), ("-", 4), ("G4", 0.5), ("A4", 0.5), ("B4", 1), ("-", 2),
            ("-", 4), ("D5", 0.5), ("C5", 0.5), ("A4", 1), ("-", 2),
            ("-", 2), ("B4", 0.5), ("D5", 0.5), ("G5", 1), ("-", 4), ("F#5", 0.5), ("D5", 0.5), ("A4", 1), ("G4", 2)]
    sequence(buf, lick, 0, beat, "square", 0.125, gain=0.22, vibrato=0.006, decay=0.05, sustain=0.4)
    write("travel.wav", buf[: int(beat * 32 * RATE)], gain=0.24)


# -------------------------------------------------------------------- sfx --

def sfx():
    b = blank(0); mix_into(b, tone(freq("E6"), 0.05, "square", 0.5, decay=0.02, sustain=0.3), 0); write("blip.wav", b, 0.18)
    b = blank(0); mix_into(b, tone(freq("B5"), 0.06, "square", 0.25), 0); mix_into(b, tone(freq("E6"), 0.1, "square", 0.25), 0.06); write("select.wav", b, 0.2)
    b = blank(0); mix_into(b, tone(freq("C3"), 0.25, "square", 0.5, slide=-0.4, decay=0.2, sustain=0.2), 0); write("bonk.wav", b, 0.25)
    b = blank(0); mix_into(b, tone(freq("B5"), 0.07, "square", 0.5), 0); mix_into(b, tone(freq("E6"), 0.25, "square", 0.5, decay=0.2, sustain=0.2), 0.07); write("coin.wav", b, 0.2)
    b = blank(0); mix_into(b, noise(0.18, 0.04), 0); mix_into(b, tone(freq("A2"), 0.12, "triangle", slide=-0.5), 0, 0.8); write("pop.wav", b, 0.3)
    b = blank(0)
    for i in range(3):
        mix_into(b, noise(0.1, 0.04, hold=6), i * 0.12); mix_into(b, tone(freq("E2"), 0.1, "square", 0.3, slide=-0.3), i * 0.12, 0.5)
    write("clunk.wav", b, 0.3)
    b = blank(0); mix_into(b, noise(1.2, 0.5, hold=14), 0); write("rumble.wav", b, 0.28)
    b = blank(0); mix_into(b, noise(0.7, 0.25, hold=1), 0); mix_into(b, tone(freq("C5"), 0.3, "sine", slide=-0.6), 0, 0.4); write("splash.wav", b, 0.3)
    b = blank(0)
    sequence(b, [("A3", 1.5), ("F3", 1.5), ("D3", 1.5), ("C#3", 3)], 0, 0.22, "triangle", gain=0.7, decay=0.2, sustain=0.6)
    sequence(b, [("A2", 1.5), ("F2", 1.5), ("D2", 1.5), ("A1", 3)], 0, 0.22, "square", 0.25, gain=0.2)
    write("death.wav", b, 0.3)
    b = blank(0)
    sequence(b, [("G4", 0.5), ("B4", 0.5), ("D5", 0.5), ("G5", 1.5), ("-", 0.25), ("E5", 0.5), ("G5", 2.5)], 0, 0.13, "square", 0.25, gain=0.6, vibrato=0.005)
    sequence(b, [("G3", 1.5), ("D3", 1.5), ("C3", 0.75), ("G3", 2.5)], 0, 0.13, "triangle", gain=0.6)
    write("fanfare.wav", b, 0.28)
    b = blank(0)
    sequence(b, [("D5", 0.5), ("G5", 0.5), ("B5", 1.5)], 0, 0.1, "square", 0.5, gain=0.6)
    write("arrive.wav", b, 0.22)
    b = blank(0)
    sequence(b, [("G4", 1), ("E4", 1), ("C4", 2)], 0, 0.2, "triangle", gain=0.6, decay=0.2, sustain=0.5)
    write("rest.wav", b, 0.25)
    b = blank(0)
    for i in range(6):
        mix_into(b, tone(freq("C6") * (1 + 0.3 * (i % 2)), 0.12, "sine", vibrato=0.06), i * 0.11)
    write("ufo.wav", b, 0.22)
    b = blank(0); mix_into(b, tone(freq("C5"), 0.12, "square", 0.25, slide=0.8, decay=0.05, sustain=0.3), 0); write("throw.wav", b, 0.18)
    b = blank(0); mix_into(b, tone(freq("G5"), 0.05, "square", 0.5), 0); mix_into(b, tone(freq("C6"), 0.05, "square", 0.5), 0.05); mix_into(b, tone(freq("G6"), 0.12, "square", 0.5), 0.1); write("hit.wav", b, 0.2)
    b = blank(0)
    mix_into(b, tone(freq("F4"), 0.18, "square", 0.4), 0, 0.5); mix_into(b, tone(freq("A4"), 0.18, "square", 0.4), 0, 0.5)
    mix_into(b, tone(freq("F4"), 0.35, "square", 0.4), 0.24, 0.5); mix_into(b, tone(freq("A4"), 0.35, "square", 0.4), 0.24, 0.5)
    write("horn.wav", b, 0.25)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    travel()
    theme()
