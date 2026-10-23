"""Beta 3.2 (ADR-029 amendment): FITOS's two chimes, made here, not sourced.

Short, soft sine tones with a fast attack and a gentle decay, quiet (peak
about -12 dB), mono 16-bit 22.05 kHz WAV. Run from apps/mobile:

    python tool/sounds.py

writes assets/sounds/rest_over.wav (two rising notes) and
assets/sounds/session_done.wav (three rising notes).
"""
import math
import os
import struct
import wave

RATE = 22050
PEAK = 0.25  # about -12 dB


def note(freq, start, length, total):
    out = [0.0] * total
    first = int(start * RATE)
    for i in range(int(length * RATE)):
        j = first + i
        if j >= total:
            break
        t = i / RATE
        attack = min(1.0, t / 0.008)
        decay = math.exp(-t / (length / 4))
        tone = math.sin(2 * math.pi * freq * t) + 0.18 * math.sin(2 * math.pi * 2 * freq * t)
        out[j] += attack * decay * tone
    return out


def write(path, notes, seconds):
    total = int(seconds * RATE)
    mix = [0.0] * total
    for freq, start, length in notes:
        for i, v in enumerate(note(freq, start, length, total)):
            mix[i] += v
    top = max(abs(v) for v in mix) or 1.0
    frames = b''.join(struct.pack('<h', int(v / top * PEAK * 32767)) for v in mix)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)


os.makedirs('assets/sounds', exist_ok=True)
# A5 then E6: "rest is over".
write('assets/sounds/rest_over.wav', [(880.0, 0.0, 0.45), (1318.5, 0.13, 0.5)], 0.7)
# C6, E6, G6: "session done".
write('assets/sounds/session_done.wav', [(1046.5, 0.0, 0.45), (1318.5, 0.11, 0.45), (1568.0, 0.22, 0.6)], 0.9)
print('wrote assets/sounds/rest_over.wav and assets/sounds/session_done.wav')
