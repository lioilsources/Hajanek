"""TTS engine adapters for the benchmark.

Every module exposes:

    class Engine:
        native_speed: bool    # True if synth() honours `speed` itself
        native_whisper: bool  # True if style == "whisper" is handled by the engine
        def __init__(self, ref_wav: str | None): ...
        def synth(self, text: str, speed: float, style: str) -> tuple[np.ndarray, int]: ...

Heavy imports happen inside Engine.__init__ so the runner works with only one
engine installed in the current venv.
"""
from __future__ import annotations

from pathlib import Path


def _read(p: Path) -> str | None:
    return p.read_text(encoding="utf-8").strip() if p.exists() else None


def ref_bundle(ref_wav: str | None) -> dict[str, str | None]:
    """Resolve sidecars next to the reference: ref.txt, ref.whisper.wav, ref.whisper.txt."""
    if not ref_wav:
        return {"wav": None, "text": None, "whisper_wav": None, "whisper_text": None}
    p = Path(ref_wav)
    w = p.with_name(f"{p.stem}.whisper.wav")
    return {
        "wav": str(p),
        "text": _read(p.with_suffix(".txt")),
        "whisper_wav": str(w) if w.exists() else None,
        "whisper_text": _read(w.with_suffix(".txt")),
    }
