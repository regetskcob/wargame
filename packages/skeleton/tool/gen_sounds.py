"""Synthesises the game's sound effects as 16 bit mono WAV files.

Run from packages/game: python3 tool/gen_sounds.py
"""
import math
import random
import struct
import wave

RATE = 22050
OUT = 'assets/audio'


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.9 / peak if peak > 0.9 else 1.0
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1, min(1, s * scale)) * 32767))
            for s in samples))


def env(i, n, attack=0.005, power=3.0):
    t = i / n
    a = min(1.0, (i / RATE) / attack) if attack else 1.0
    return a * (1 - t) ** power


def noise_lp(n, cutoff):
    """White noise through a one pole low pass."""
    out, y = [], 0.0
    k = cutoff
    for _ in range(n):
        y += k * (random.uniform(-1, 1) - y)
        out.append(y)
    return out


def cannon():
    n = int(RATE * 0.55)
    hiss = noise_lp(n, 0.35)
    return [
        (0.8 * math.sin(2 * math.pi * (95 - 55 * i / n) * i / RATE)
         + 0.9 * hiss[i]) * env(i, n, 0.001, 2.6)
        for i in range(n)
    ]


def autocannon():
    n = int(RATE * 0.16)
    hiss = noise_lp(n, 0.6)
    return [
        (0.55 * math.sin(2 * math.pi * 150 * i / RATE) + hiss[i])
        * env(i, n, 0.0005, 2.0)
        for i in range(n)
    ]


def hit():
    n = int(RATE * 0.28)
    return [
        (math.sin(2 * math.pi * 820 * i / RATE)
         + 0.7 * math.sin(2 * math.pi * 1370 * i / RATE)
         + 0.5 * math.sin(2 * math.pi * 2190 * i / RATE)
         + 0.6 * random.uniform(-1, 1)) * env(i, n, 0.0005, 5.0) * 0.6
        for i in range(n)
    ]


def explosion():
    n = int(RATE * 1.3)
    rumble = noise_lp(n, 0.07)
    crack = noise_lp(n, 0.5)
    return [
        (2.2 * rumble[i] * env(i, n, 0.003, 1.6)
         + 0.8 * crack[i] * env(i, n, 0.001, 8.0)
         + 0.6 * math.sin(2 * math.pi * (60 - 30 * i / n) * i / RATE)
         * env(i, n, 0.003, 2.0))
        for i in range(n)
    ]


def beep(freq=880, length=0.14):
    n = int(RATE * length)
    return [math.sin(2 * math.pi * freq * i / RATE) * env(i, n, 0.004, 1.2)
            * 0.6 for i in range(n)]


def jingle(notes, step, wave_fn):
    out = []
    for freq, length in notes:
        n = int(RATE * length)
        out += [wave_fn(freq, i) * env(i, n, 0.01, 1.4) * 0.5
                for i in range(n)]
    return out


def saw_soft(freq, i):
    t = i / RATE
    return (math.sin(2 * math.pi * freq * t)
            + 0.4 * math.sin(4 * math.pi * freq * t)
            + 0.2 * math.sin(6 * math.pi * freq * t))


def engine():
    """One second that loops cleanly: only whole periods of every tone."""
    n = RATE
    out = []
    for i in range(n):
        t = i / RATE
        v = (0.6 * math.sin(2 * math.pi * 48 * t)
             + 0.4 * math.sin(2 * math.pi * 96 * t)
             + 0.25 * math.sin(2 * math.pi * 144 * t)
             + 0.15 * math.sin(2 * math.pi * 72 * t))
        v *= 0.75 + 0.25 * math.sin(2 * math.pi * 12 * t)
        out.append(v * 0.5)
    return out


def squish():
    n = int(RATE * 0.22)
    thud = noise_lp(n, 0.12)
    return [
        (0.9 * math.sin(2 * math.pi * (140 - 80 * i / n) * i / RATE)
         + 1.4 * thud[i]) * env(i, n, 0.002, 3.0)
        for i in range(n)
    ]


random.seed(5)
write('cannon', cannon())
write('autocannon', autocannon())
write('hit', hit())
write('explosion', explosion())
write('tick', beep(880, 0.12))
write('go', beep(1320, 0.42))
write('win', jingle(
    [(523, 0.16), (659, 0.16), (784, 0.16), (1047, 0.55)], 0, saw_soft))
write('lose', jingle(
    [(392, 0.22), (349, 0.22), (311, 0.22), (233, 0.7)], 0, saw_soft))
write('engine', engine())
write('squish', squish())
print('ok')
