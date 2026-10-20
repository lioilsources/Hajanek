"""Dummy engine: quiet syllable-modulated tone + pink noise, words/2.5 s long.

Pure stdlib so the whole pipeline runs without GPU or numpy.
"""
from __future__ import annotations

import math
import random
import struct
import wave
import zlib

from .base import Engine, SynthResult

RATE = 24000


def word_count(text: str) -> int:
    return max(1, sum(1 for w in text.split() if any(c.isalnum() for c in w)))


class DummyEngine(Engine):
    name = "dummy"
    native_styles = frozenset({"whisper"})  # whisper = noise only, so no fallback needed

    def __init__(self, **_):
        pass

    def synthesize(self, text, speed, style, voice_ref, out_path):
        speed = speed or 1.0
        dur = word_count(text) / 2.5 / speed
        n = int(dur * RATE)
        rng = random.Random(zlib.crc32(text.encode()))
        # Paul Kellet's economy pink noise filter.
        b0 = b1 = b2 = 0.0
        f0 = 140.0 + (zlib.crc32((voice_ref or "").encode()) % 80)
        whisper = style == "whisper"
        tone_amp = 0.0 if whisper else 0.12
        noise_amp = 0.10 if whisper else 0.03
        syl = 4.0 * speed  # syllables per second
        frames = bytearray()
        two_pi = 2 * math.pi
        for i in range(n):
            t = i / RATE
            w = rng.uniform(-1, 1)
            b0 = 0.99765 * b0 + w * 0.0990460
            b1 = 0.96300 * b1 + w * 0.2965164
            b2 = 0.57000 * b2 + w * 1.0526913
            pink = (b0 + b1 + b2 + w * 0.1848) * 0.2
            env = 0.5 - 0.5 * math.cos(two_pi * syl * t)
            edge = min(1.0, t / 0.03, (dur - t) / 0.03)
            s = (tone_amp * math.sin(two_pi * f0 * t) + noise_amp * pink) * env * edge
            frames += struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
        with wave.open(out_path, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(RATE)
            wf.writeframes(bytes(frames))
        return SynthResult(duration_s=n / RATE, style_applied=style in self.native_styles)
