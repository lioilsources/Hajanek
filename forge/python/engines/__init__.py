"""TTS engine adapter registry. Engine choice: docs/adr/ADR-001-tts-engine.md."""
from __future__ import annotations

import importlib

from .base import Engine, SynthResult

# name -> "module:Class" (imported lazily so heavy deps load only when used)
REGISTRY: dict[str, str] = {
    "dummy": "engines.dummy:DummyEngine",
    # ADR-001 shortlist; thin wrappers over forge/python/bench/engines (unverified in pipeline)
    "dots": "engines.bench_adapter:DotsEngine",      # dots.tts-soar, provisional default
    "moss": "engines.bench_adapter:MossEngine",      # MOSS-TTS v1.5, backup
    "pocket": "engines.bench_adapter:PocketEngine",  # Pocket TTS Czech, CPU fallback
}


def load(name: str, **kwargs) -> Engine:
    if name not in REGISTRY:
        raise KeyError(f"unknown TTS engine {name!r}; known: {', '.join(sorted(REGISTRY))}")
    mod_name, cls_name = REGISTRY[name].split(":")
    cls = getattr(importlib.import_module(mod_name), cls_name)
    return cls(**kwargs)


__all__ = ["Engine", "SynthResult", "REGISTRY", "load"]
