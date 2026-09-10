"""Generate assets/sounds/default_alarm.wav — a synthesised, seamlessly
looping 2-second alarm tone (4 beeps, then silence). Fully original, so
there is no licensing question; swap the file for a licensed tone anytime.

Run from the repo root:  python tools/gen_alarm.py
"""

import math
import os
import struct
import wave

SR = 44100
PHRASE = 2.0                      # seconds; loops seamlessly
F1, F2 = 830.0, 1245.0           # fundamental + fifth
BEEP_ON, BEEP_GAP, BEEPS = 0.15, 0.10, 4
AMP = 0.55
ATK = REL = 0.010               # click-free envelope

OUT = os.path.join("assets", "sounds", "default_alarm.wav")


def sample(t: float) -> float:
    block = BEEP_ON + BEEP_GAP
    if t >= BEEPS * block:
        return 0.0
    pos = t % block
    if pos >= BEEP_ON:
        return 0.0
    if pos < ATK:
        env = pos / ATK
    elif pos > BEEP_ON - REL:
        env = (BEEP_ON - pos) / REL
    else:
        env = 1.0
    s = math.sin(2 * math.pi * F1 * t) + 0.35 * math.sin(2 * math.pi * F2 * t)
    return AMP * env * s / 1.35


def main() -> None:
    n = int(SR * PHRASE)
    frames = bytearray()
    for i in range(n):
        v = int(max(-1.0, min(1.0, sample(i / SR))) * 32767)
        frames += struct.pack("<h", v)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f"wrote {OUT} ({os.path.getsize(OUT)} bytes)")


if __name__ == "__main__":
    main()
