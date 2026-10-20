"""Pocket TTS Czech adapter (CC-BY-4.0 weights) — https://huggingface.co/vvolhejn/pocket-tts-czech

API per kyutai-labs/pocket-tts README: TTSModel.load_model(config=..., temp=...),
get_state_for_audio_prompt(wav), generate_audio(state, text) -> 1D torch tensor,
model.sample_rate. No speed control (runner time-stretches). Runs on CPU.
"""
from __future__ import annotations

import os

import numpy as np

from . import ref_bundle

# Pinned revision as recommended by the model card.
CONFIG = os.environ.get(
    "POCKET_CONFIG",
    "hf://vvolhejn/pocket-tts-czech/czech.yaml@7c1fbd0acba765617749dd17f3dbddc2be791cc7",
)


class Engine:
    native_speed = False

    def __init__(self, ref_wav: str | None):
        from pocket_tts import TTSModel

        self.model_id = CONFIG
        self.ref = ref_bundle(ref_wav)
        if not self.ref["wav"]:
            raise ValueError("pocket-tts-czech needs a reference voice (--ref); catalog voices don't work with it")
        self.model = TTSModel.load_model(config=CONFIG, temp=0.3)
        if os.environ.get("POCKET_DEVICE"):
            self.model.to(os.environ["POCKET_DEVICE"])
        self.state = self.model.get_state_for_audio_prompt(self.ref["wav"])
        self.whisper_state = (
            self.model.get_state_for_audio_prompt(self.ref["whisper_wav"]) if self.ref["whisper_wav"] else None
        )
        self.native_whisper = self.whisper_state is not None

    def synth(self, text: str, speed: float, style: str) -> tuple[np.ndarray, int]:
        state = self.whisper_state if style == "whisper" and self.whisper_state is not None else self.state
        audio = self.model.generate_audio(state, text)
        return audio.detach().cpu().numpy(), int(self.model.sample_rate)
