from __future__ import annotations

from dataclasses import dataclass


@dataclass
class SynthResult:
    duration_s: float
    # True when the engine rendered `style` natively (e.g. whisper mode);
    # otherwise forge applies the CONTRACTS §2 fallback (low-pass + gain).
    style_applied: bool = False


class Engine:
    """Adapter interface. Implementations write a WAV file (any rate, mono) to out_path."""

    name = "base"
    native_styles: frozenset[str] = frozenset()

    def synthesize(self, text: str, speed: float, style: str, voice_ref: str | None,
                   out_path: str) -> SynthResult:
        raise NotImplementedError

    def close(self) -> None:
        pass
