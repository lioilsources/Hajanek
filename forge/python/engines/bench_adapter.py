"""Adapter over the benchmark engines in forge/python/bench/engines/ (ADR-001 shortlist).

Reuses bench adapters (one instance per voice reference). Untested in the
pipeline until ADR-001 is final; run the engine in its own uv venv (see
forge/python/bench/README.md). Speed: engines without native speed control are
time-stretched with ffmpeg atempo (pitch-preserving).
"""
from __future__ import annotations

import importlib
import os
import subprocess
import wave

from .base import Engine, SynthResult

ADR = "docs/adr/ADR-001-tts-engine.md"


def _write_wav(path: str, audio, sr: int) -> float:
    import numpy as np
    x = np.asarray(audio, dtype=np.float32).squeeze()
    if x.ndim > 1:
        x = x.mean(axis=0 if x.shape[0] < x.shape[-1] else -1)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(pcm)
    return len(x) / sr


def _atempo(path: str, speed: float) -> None:
    tmp = path + ".tempo.wav"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-af", f"atempo={speed:.4f}", tmp], check=True)
    os.replace(tmp, path)


class BenchEngine(Engine):
    bench_module = ""

    def __init__(self, **_):
        try:
            self._mod = importlib.import_module(f"bench.engines.{self.bench_module}")
        except ImportError as e:
            raise NotImplementedError(
                f"engine {self.name!r}: bench adapter not importable ({e}); install the engine venv "
                f"per forge/python/bench/README.md, see {ADR}") from e
        self._instances: dict[str, object] = {}

    def _engine(self, voice_ref: str | None):
        key = voice_ref or ""
        if key not in self._instances:
            self._instances[key] = self._mod.Engine(voice_ref)
        return self._instances[key]

    def synthesize(self, text, speed, style, voice_ref, out_path):
        eng = self._engine(voice_ref)
        native_speed = bool(getattr(eng, "native_speed", False))
        audio, sr = eng.synth(text, speed if native_speed else 1.0, style)
        dur = _write_wav(out_path, audio, sr)
        if not native_speed and abs(speed - 1.0) > 1e-3:
            _atempo(out_path, speed)
            dur /= speed
        native_whisper = bool(getattr(eng, "native_whisper", False))
        return SynthResult(duration_s=dur, style_applied=(style != "whisper") or native_whisper)


class DotsEngine(BenchEngine):
    name = bench_module = "dots"


class MossEngine(BenchEngine):
    name = bench_module = "moss"


class PocketEngine(BenchEngine):
    name = bench_module = "pocket"
