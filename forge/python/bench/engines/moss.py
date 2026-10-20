"""MOSS-TTS v1.5 adapter (Apache-2.0) — https://huggingface.co/OpenMOSS-Team/MOSS-TTS-v1.5

API per model card: AutoProcessor/AutoModel with trust_remote_code,
processor.build_user_message(text=..., reference=[wav], language="Czech", tokens=N),
model.generate(...), processor.decode(...) -> message.audio_codes_list[0].
Speed is approximated via duration control (1 s ~= 12.5 audio tokens).
"""
from __future__ import annotations

import os

import numpy as np

from . import ref_bundle

MODEL_ID = os.environ.get("MOSS_MODEL", "OpenMOSS-Team/MOSS-TTS-v1.5")
TOKENS_PER_S = 12.5
CHARS_PER_S = 14.0  # rough natural Czech reading rate at 1.0x; tune after first run


class Engine:
    native_speed = True

    def __init__(self, ref_wav: str | None):
        import torch
        from transformers import AutoModel, AutoProcessor

        self.torch = torch
        self.model_id = MODEL_ID
        self.ref = ref_bundle(ref_wav)
        self.native_whisper = bool(self.ref["whisper_wav"])
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        dtype = torch.bfloat16 if self.device == "cuda" else torch.float32
        if self.device == "cuda":
            torch.backends.cuda.enable_cudnn_sdp(False)  # per model card
        self.proc = AutoProcessor.from_pretrained(MODEL_ID, trust_remote_code=True)
        self.proc.audio_tokenizer = self.proc.audio_tokenizer.to(self.device)
        self.model = AutoModel.from_pretrained(
            MODEL_ID, trust_remote_code=True, attn_implementation="sdpa", torch_dtype=dtype
        ).to(self.device).eval()
        self.sr = int(self.proc.model_config.sampling_rate)

    def synth(self, text: str, speed: float, style: str) -> tuple[np.ndarray, int]:
        msg = {"text": text, "language": "Czech"}
        wav = self.ref["whisper_wav"] if style == "whisper" and self.native_whisper else self.ref["wav"]
        if wav:
            msg["reference"] = [wav]
        if abs(speed - 1.0) > 1e-3:
            seconds = len(text) / CHARS_PER_S / speed
            msg["tokens"] = max(1, round(seconds * TOKENS_PER_S))
        batch = self.proc([[self.proc.build_user_message(**msg)]], mode="generation")
        with self.torch.no_grad():
            out = self.model.generate(
                input_ids=batch["input_ids"].to(self.device),
                attention_mask=batch["attention_mask"].to(self.device),
                max_new_tokens=4096,
            )
        audio = next(iter(self.proc.decode(out))).audio_codes_list[0]
        return audio.float().cpu().numpy(), self.sr
