"""Minimal python mirror of forge/internal/script (CONTRACTS §2).

The Go parser is authoritative (and validates); this one only extracts
utterances and pauses for standalone tools (qa_worker --script, bench).
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

SECTIONS = ("uvod", "vstup", "pribeh", "dojezd")
_COMMENT = re.compile(r"<!--.*?-->", re.S)
_PAUSE = re.compile(r"^\[pause\s+(\d+(?:\.\d+)?)\s*s\]$")
_TONE = re.compile(r"^\[(soft|slow|whisper)\]\s*")
_PH = re.compile(r"\{\{\s*[^{}|]*?\s*(?:\|([^{}]*))?\}\}")


@dataclass
class Item:
    section: str
    kind: str  # "utterance" | "pause"
    text: str = ""
    tone: str = "soft"
    pause_s: float = 0.0


@dataclass
class Script:
    meta_raw: str = ""
    items: list[Item] = field(default_factory=list)

    def utterances(self) -> list[Item]:
        return [i for i in self.items if i.kind == "utterance"]

    def plain_text(self) -> str:
        return "\n".join(u.text for u in self.utterances())


def parse(src: str) -> Script:
    src = _COMMENT.sub(lambda m: "\n" * m.group(0).count("\n"), src.replace("\r\n", "\n"))
    lines = src.split("\n")
    s = Script()
    start = 0
    if lines and lines[0].strip() == "---":
        end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
        s.meta_raw = "\n".join(lines[1:end])
        start = end + 1
    section, tone = None, "soft"
    for raw in lines[start:]:
        line = raw.strip()
        if not line:
            continue
        if line.startswith("## "):
            section, tone = line[3:].strip().lower(), "soft"
            continue
        if section is None:
            continue
        m = _PAUSE.match(line)
        if m:
            s.items.append(Item(section, "pause", pause_s=float(m.group(1))))
            continue
        m = _TONE.match(line)
        if m:
            tone, line = m.group(1), line[m.end():].strip()
            if not line:
                continue
        text = _PH.sub(lambda m: (m.group(1) or "").strip(), line)
        s.items.append(Item(section, "utterance", text=text, tone=tone))
    return s


def parse_file(path: str) -> Script:
    with open(path, encoding="utf-8") as f:
        return parse(f.read())
