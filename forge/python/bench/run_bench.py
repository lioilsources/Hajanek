#!/usr/bin/env python3
"""Engine-agnostic TTS benchmark runner (ADR-001).

Parses a meditation script (CONTRACTS.md §2), synthesizes every utterance
with one engine adapter, inserts pauses, applies tone gain / whisper fallback,
and writes out/{engine}/sample.wav + out/{engine}/timing.json.

Usage:
    python run_bench.py --engine dots --ref refs/ref.wav [--script sample_cs.md]
"""
from __future__ import annotations

import argparse
import importlib
import json
import re
import time
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
SECTIONS = ("uvod", "vstup", "pribeh", "dojezd")

# CONTRACTS.md §2 defaults: tone -> (speed, gain_db)
TONES = {"soft": (0.85, 0.0), "slow": (0.78, -3.0), "whisper": (0.75, -10.0)}
DOJEZD_END_SPEED, DOJEZD_END_GAIN = 0.75, -6.0
WHISPER_LOWPASS_HZ = 3500.0

PAUSE_RE = re.compile(r"^\[pause\s+(\d+(?:\.\d+)?)s\]$")
TONE_RE = re.compile(r"^\[(soft|slow|whisper)\]\s*")
NAME_RE = re.compile(r"\{\{[^|}]*\|([^}]*)\}\}")
COMMENT_RE = re.compile(r"<!--.*?-->", re.S)


@dataclass
class Item:
    section: str
    text: str | None = None  # None => pause
    pause_s: float = 0.0
    style: str = "soft"
    speed: float = 1.0
    gain_db: float = 0.0


def parse_script(src: str) -> list[Item]:
    """Simple parser mirroring CONTRACTS.md §2 (front matter is skipped)."""
    src = COMMENT_RE.sub("", src)
    if src.startswith("---"):
        src = src.split("---", 2)[2]
    items: list[Item] = []
    section, style = None, "soft"
    for raw in src.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("## "):
            section, style = line[3:].strip(), "soft"
            if section not in SECTIONS:
                raise ValueError(f"unknown section: {section}")
            continue
        if section is None:
            continue
        if m := PAUSE_RE.match(line):
            items.append(Item(section, pause_s=float(m.group(1))))
            continue
        if m := TONE_RE.match(line):
            style, line = m.group(1), line[m.end():]
            if not line:
                continue
        text = NAME_RE.sub(r"\1", line)  # MVP: always the fallback
        speed, gain = TONES[style]
        items.append(Item(section, text=text, style=style, speed=speed, gain_db=gain))

    # dojezd: speed ramps down to 0.75x and gain to -6 dB across the section
    dj = [it for it in items if it.section == "dojezd" and it.text]
    for i, it in enumerate(dj):
        t = i / max(len(dj) - 1, 1)
        ramp_speed = TONES["soft"][0] + (DOJEZD_END_SPEED - TONES["soft"][0]) * t
        it.speed = min(it.speed, ramp_speed)
        it.gain_db = min(it.gain_db, DOJEZD_END_GAIN * t)
    return items


def lowpass(x: np.ndarray, sr: int, cutoff: float) -> np.ndarray:
    """Brick-wall FFT low-pass; good enough for a whisper fallback in a benchmark."""
    spec = np.fft.rfft(x)
    spec[np.fft.rfftfreq(len(x), 1.0 / sr) > cutoff] = 0
    return np.fft.irfft(spec, n=len(x)).astype(np.float32)


def time_stretch(x: np.ndarray, rate: float) -> np.ndarray:
    """rate < 1 slows down (librosa phase vocoder)."""
    if abs(rate - 1.0) < 1e-3:
        return x
    try:
        import librosa
    except ImportError:
        raise SystemExit("librosa is required for engines without native speed: uv pip install librosa")
    return librosa.effects.time_stretch(x, rate=rate).astype(np.float32)


def to_mono_f32(audio) -> np.ndarray:
    a = np.asarray(audio, dtype=np.float32)
    return a.mean(axis=0 if a.shape[0] < a.shape[-1] else 1) if a.ndim > 1 else a


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--engine", required=True, help="adapter module in engines/ (dots, moss, pocket)")
    ap.add_argument("--ref", default=None, help="reference wav; ref.txt / ref.whisper.wav sidecars optional")
    ap.add_argument("--script", default=str(HERE / "sample_cs.md"))
    ap.add_argument("--out", default=str(HERE / "out"))
    args = ap.parse_args()

    items = parse_script(Path(args.script).read_text(encoding="utf-8"))
    mod = importlib.import_module(f"engines.{args.engine}")

    t0 = time.perf_counter()
    engine = mod.Engine(args.ref)
    load_s = time.perf_counter() - t0
    native_speed = getattr(engine, "native_speed", False)
    native_whisper = getattr(engine, "native_whisper", False)

    chunks: list[np.ndarray] = []
    rows, sr = [], None
    pending_pause = 0.0
    for it in items:
        if it.text is None:
            pending_pause += it.pause_s
            continue
        t1 = time.perf_counter()
        audio, r = engine.synth(it.text, it.speed if native_speed else 1.0, it.style)
        synth_s = time.perf_counter() - t1
        if sr is None:
            sr = r
        elif r != sr:
            raise RuntimeError(f"engine changed sample rate {sr} -> {r}")
        audio = to_mono_f32(audio)
        if not native_speed:
            audio = time_stretch(audio, it.speed)
        if it.style == "whisper" and not native_whisper:
            audio = lowpass(audio, sr, WHISPER_LOWPASS_HZ)
        audio *= 10 ** (it.gain_db / 20)
        if pending_pause:
            chunks.append(np.zeros(int(pending_pause * sr), np.float32))
            pending_pause = 0.0
        chunks.append(audio)
        dur = len(audio) / sr
        rows.append({"section": it.section, "style": it.style, "speed": round(it.speed, 3),
                     "gain_db": round(it.gain_db, 2), "text": it.text,
                     "synth_s": round(synth_s, 3), "audio_s": round(dur, 3)})
        print(f"[{it.section:6}] {it.style:7} x{it.speed:.2f} {synth_s:6.2f}s -> {dur:5.2f}s  {it.text}")
    if sr is None:
        raise SystemExit("script contains no utterances")
    if pending_pause:
        chunks.append(np.zeros(int(pending_pause * sr), np.float32))

    wav = np.concatenate(chunks)
    peak = float(np.abs(wav).max())
    if peak > 0.99:  # avoid clipping; loudness is normalized later (ffmpeg loudnorm)
        wav *= 0.99 / peak

    out_dir = Path(args.out) / args.engine
    out_dir.mkdir(parents=True, exist_ok=True)
    sf.write(out_dir / "sample.wav", wav, sr)
    synth_total = sum(r["synth_s"] for r in rows)
    voice_total = sum(r["audio_s"] for r in rows)
    timing = {
        "engine": args.engine, "model": getattr(engine, "model_id", None),
        "sample_rate": sr, "load_s": round(load_s, 2),
        "synth_s": round(synth_total, 2), "voice_audio_s": round(voice_total, 2),
        "total_audio_s": round(len(wav) / sr, 2),
        "rtf": round(synth_total / voice_total, 4) if voice_total else None,
        "native_speed": native_speed, "native_whisper": native_whisper,
        "utterances": rows,
    }
    (out_dir / "timing.json").write_text(json.dumps(timing, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n{out_dir / 'sample.wav'}  {timing['total_audio_s']}s  RTF={timing['rtf']}  load={timing['load_s']}s")


if __name__ == "__main__":
    main()
