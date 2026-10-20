#!/usr/bin/env python3
"""QA worker: ASR WER + signal checks on a mastered track. Prints a JSON report.

Request (stdin JSON or --request FILE):
  {"audio", "reference_text", "intended_silences": [[start_s, end_s], ...],
   "thresholds": {"wer_max", "silence_max_s", "silence_db", "clip_dbfs",
                  "hf_cutoff_hz", "hf_max_rel_db", "long_pause_slack_s"},
   "whisper_model", "language"}
Standalone: qa_worker.py --audio X.opus --script content/scripts/foo.10.md

Backends: faster-whisper for ASR (skipped with a warning when missing);
numpy for signal checks, falling back to ffmpeg astats/silencedetect.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import subprocess
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

DEFAULTS = {"wer_max": 0.05, "silence_max_s": 15.0, "silence_db": -50.0, "clip_dbfs": -0.1,
            "hf_cutoff_hz": 10000.0, "hf_max_rel_db": -35.0, "long_pause_slack_s": 3.0}


def log(msg: str) -> None:
    print(f"qa_worker: {msg}", file=sys.stderr)


# ---------- text ----------

def normalize_cs(text: str) -> list[str]:
    text = unicodedata.normalize("NFC", text.lower())
    text = re.sub(r"\[[^\]]*\]", " ", text)           # leftover markup
    text = re.sub(r"\{\{[^}|]*\|?([^}]*)\}\}", r"\1", text)
    text = "".join(c if c.isalnum() or c.isspace() else " " for c in text)
    return text.split()


def wer(ref: list[str], hyp: list[str]) -> float:
    if not ref:
        return 0.0 if not hyp else 1.0
    prev = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, 1):
        cur = [i] + [0] * len(hyp)
        for j, h in enumerate(hyp, 1):
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (r != h))
        prev = cur
    return prev[-1] / len(ref)


def run_asr(audio: str, model_name: str, language: str):
    try:
        from faster_whisper import WhisperModel  # lazy: heavy optional dep
    except ImportError:
        return None
    device = os.environ.get("WHISPER_DEVICE", "auto")
    compute = os.environ.get("WHISPER_COMPUTE", "default")
    model = WhisperModel(model_name, device=device, compute_type=compute)
    segments, _ = model.transcribe(audio, language=language, beam_size=5, vad_filter=False)
    return " ".join(s.text.strip() for s in segments)


# ---------- signal: numpy backend ----------

def decode_f32(audio: str, rate: int = 48000):
    import numpy as np
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", audio, "-ac", "1", "-ar", str(rate),
                          "-f", "f32le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32), rate


def signal_numpy(audio: str, th: dict) -> dict:
    import numpy as np
    x, rate = decode_f32(audio)
    peak = float(np.max(np.abs(x))) if x.size else 0.0
    clip_lin = 10 ** (th["clip_dbfs"] / 20)
    clipped = int(np.sum(np.abs(x) >= clip_lin))
    hop = int(0.05 * rate)
    n = len(x) // hop
    frames = x[: n * hop].reshape(n, hop)
    rms_db = 10 * np.log10(np.mean(frames ** 2, axis=1) + 1e-20)
    silent = rms_db < th["silence_db"]
    silences, start = [], None
    for i, s in enumerate(list(silent) + [False]):
        if s and start is None:
            start = i
        elif not s and start is not None:
            silences.append((start * hop / rate, i * hop / rate))
            start = None
    # HF energy ratio via averaged power spectrum.
    win = 8192
    segs = len(x) // win
    if segs:
        spec = np.zeros(win // 2 + 1)
        w = np.hanning(win)
        step = max(1, segs // 200)
        for k in range(0, segs, step):
            spec += np.abs(np.fft.rfft(x[k * win:(k + 1) * win] * w)) ** 2
        freqs = np.fft.rfftfreq(win, 1 / rate)
        hf = spec[freqs >= th["hf_cutoff_hz"]].sum()
        hf_rel = 10 * math.log10((hf + 1e-20) / (spec.sum() + 1e-20))
    else:
        hf_rel = -120.0
    rms = float(np.sqrt(np.mean(x ** 2))) if x.size else 0.0
    return {"backend": "numpy", "duration_s": len(x) / rate,
            "peak_dbfs": 20 * math.log10(peak + 1e-12), "rms_dbfs": 20 * math.log10(rms + 1e-12),
            "clipped_samples": clipped, "silences": silences, "hf_rel_db": hf_rel}


# ---------- signal: ffmpeg backend ----------

def _ffmpeg_stderr(args: list[str]) -> str:
    return subprocess.run(["ffmpeg", "-hide_banner", "-nostats", *args, "-f", "null", "-"],
                          capture_output=True, text=True, check=True).stderr


def _astats_overall(stderr: str) -> dict:
    i = stderr.rfind("Overall")
    block = stderr[i:] if i >= 0 else stderr
    out = {}
    for key, name in (("Peak level dB", "peak"), ("RMS level dB", "rms"), ("Peak count", "peak_count"),
                      ("Number of samples", "samples")):
        m = re.search(re.escape(key) + r":\s*(-?[\d.]+|-inf)", block)
        if m:
            out[name] = -120.0 if m.group(1) == "-inf" else float(m.group(1))
    return out


def signal_ffmpeg(audio: str, th: dict) -> dict:
    full = _astats_overall(_ffmpeg_stderr(["-i", audio, "-af", "aresample=48000,astats=metadata=0"]))
    c = th["hf_cutoff_hz"]
    hf = _astats_overall(_ffmpeg_stderr(
        ["-i", audio, "-af", f"aresample=48000,highpass=f={c},highpass=f={c},highpass=f={c},astats=metadata=0"]))
    sd = _ffmpeg_stderr(["-i", audio, "-af", f"silencedetect=noise={th['silence_db']}dB:d=1"])
    starts = [float(v) for v in re.findall(r"silence_start: (-?[\d.]+)", sd)]
    ends = [float(v) for v in re.findall(r"silence_end: (-?[\d.]+)", sd)]
    dur_m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", sd)
    duration = (int(dur_m.group(1)) * 3600 + int(dur_m.group(2)) * 60 + float(dur_m.group(3))) if dur_m else 0.0
    if len(ends) < len(starts):
        ends.append(duration)
    peak = full.get("peak", -120.0)
    # astats has no clip counter; treat peak samples at/above threshold as clipped.
    clipped = int(full.get("peak_count", 0)) if peak >= th["clip_dbfs"] else 0
    return {"backend": "ffmpeg", "duration_s": duration, "peak_dbfs": peak, "rms_dbfs": full.get("rms", -120.0),
            "clipped_samples": clipped, "silences": list(zip(starts, ends)),
            "hf_rel_db": hf.get("rms", -120.0) - full.get("rms", -120.0)}


# ---------- checks ----------

def excused(sil, intended, max_s, slack) -> bool:
    s, e = sil
    for a, b in intended:
        if b - a < max_s - slack:
            continue
        overlap = min(e, b) - max(s, a)
        if overlap >= 0.5 * (e - s) and (e - s) <= (b - a) + slack:
            return True
    return False


def run(req: dict) -> dict:
    th = {**DEFAULTS, **(req.get("thresholds") or {})}
    audio = req["audio"]
    errors, warnings = [], []
    report = {"audio": audio, "thresholds": th}

    try:
        import numpy  # noqa: F401
        sig = signal_numpy(audio, th)
    except ImportError:
        warnings.append("numpy missing: signal checks via ffmpeg astats/silencedetect")
        sig = signal_ffmpeg(audio, th)
    long_sil = [(round(s, 2), round(e, 2)) for s, e in sig.pop("silences") if e - s > th["silence_max_s"]]
    intended = req.get("intended_silences") or []
    bad = [x for x in long_sil if not excused(x, intended, th["silence_max_s"], th["long_pause_slack_s"])]
    sig["long_silences"] = long_sil
    sig["unexpected_long_silences"] = bad
    report["signal"] = sig
    if sig["clipped_samples"] > 0:
        errors.append(f"clipping: {sig['clipped_samples']} samples at/above {th['clip_dbfs']} dBFS")
    if bad:
        errors.append(f"silence > {th['silence_max_s']}s not in script: {bad}")
    if sig["hf_rel_db"] > th["hf_max_rel_db"]:
        errors.append(f"HF energy above {th['hf_cutoff_hz']:.0f} Hz is {sig['hf_rel_db']:.1f} dB "
                      f"(max {th['hf_max_rel_db']} dB)")

    ref_text = req.get("reference_text") or ""
    asr = {"skipped": True}
    if os.environ.get("FORGE_QA_SKIP_ASR"):
        warnings.append("ASR skipped (FORGE_QA_SKIP_ASR)")
    else:
        try:
            hyp = run_asr(audio, req.get("whisper_model", "large-v3"), req.get("language", "cs"))
        except Exception as e:  # model download / GPU problems should not hide signal checks
            hyp = None
            errors.append(f"ASR failed: {type(e).__name__}: {e}")
        if hyp is None and not any(e.startswith("ASR failed") for e in errors):
            warnings.append("faster-whisper not installed: ASR/WER skipped (uv sync --extra whisper)")
        elif hyp is not None:
            r, h = normalize_cs(ref_text), normalize_cs(hyp)
            asr = {"skipped": False, "wer": round(wer(r, h), 4), "ref_words": len(r), "hyp_words": len(h),
                   "hypothesis": hyp[:2000]}
            if asr["wer"] > th["wer_max"]:
                errors.append(f"WER {asr['wer']:.3f} > {th['wer_max']}")
    report["asr"] = asr
    report["errors"], report["warnings"] = errors, warnings
    report["ok"] = not errors
    return report


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--request")
    ap.add_argument("--audio")
    ap.add_argument("--script")
    args = ap.parse_args()
    if args.audio:
        req = {"audio": args.audio}
        if args.script:
            import script_parser
            s = script_parser.parse_file(args.script)
            req["reference_text"] = s.plain_text()
    elif args.request:
        with open(args.request, encoding="utf-8") as f:
            req = json.load(f)
    else:
        req = json.load(sys.stdin)
    rep = run(req)
    json.dump(rep, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0 if rep["ok"] else 2


if __name__ == "__main__":
    sys.exit(main())
