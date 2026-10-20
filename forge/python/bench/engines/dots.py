"""dots.tts adapter (Apache-2.0) — https://github.com/studio-dots-ai/dots.tts

API per README: DotsTtsRuntime.from_pretrained(...).generate(text=..., prompt_audio_path=...,
prompt_text=..., num_steps=..., guidance_scale=...) -> {"audio": Tensor, "sample_rate": int}.
No documented speed/whisper control: the runner time-stretches, and a whispered
reference (ref.whisper.wav) is used for style == "whisper" when present.
"""
from __future__ import annotations

import os

import numpy as np

from . import ref_bundle

MODEL_ID = os.environ.get("DOTS_MODEL", "dots-studio/dots.tts-soar")


class Engine:
    native_speed = False

    def __init__(self, ref_wav: str | None):
        from dots_tts.runtime import DotsTtsRuntime

        self.model_id = MODEL_ID
        self.ref = ref_bundle(ref_wav)
        if not self.ref["wav"]:
            raise ValueError("dots.tts needs a reference voice (--ref); base checkpoints have no default speaker")
        self.native_whisper = bool(self.ref["whisper_wav"])
        self.rt = DotsTtsRuntime.from_pretrained(
            MODEL_ID, precision="bfloat16", optimize=os.environ.get("DOTS_COMPILE") == "1"
        )

    def synth(self, text: str, speed: float, style: str) -> tuple[np.ndarray, int]:
        whisper = style == "whisper" and self.native_whisper
        wav = self.ref["whisper_wav"] if whisper else self.ref["wav"]
        ref_text = self.ref["whisper_text"] if whisper else self.ref["text"]
        kwargs = {"text": text, "prompt_audio_path": wav, "num_steps": 10, "guidance_scale": 1.2}
        if ref_text:  # continuation cloning (best SIM); without it x-vector-only cloning
            kwargs["prompt_text"] = ref_text
        res = self.rt.generate(**kwargs)
        return res["audio"].float().cpu().squeeze().numpy(), int(res["sample_rate"])
