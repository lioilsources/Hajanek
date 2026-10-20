#!/usr/bin/env python3
"""Anonymize benchmark outputs for the blind listening test (ADR-001 §7).

Reads out/*/sample.wav, copies them in random order to blind/A.wav, B.wav, ...,
writes the hidden key to blind/.key.json and a rating sheet blind/rating_sheet.csv
where every rater gets an independent random listening order.

Usage:
    python make_blind_sheet.py [--raters 5] [--seed 42]
"""
from __future__ import annotations

import argparse
import csv
import json
import random
import shutil
import string
from pathlib import Path

HERE = Path(__file__).resolve().parent
COLUMNS = ["rater", "order", "sample", "prijemnost_1_5", "srozumitelnost_1_5", "prirozenost_cs_1_5", "poznamka"]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(HERE / "out"))
    ap.add_argument("--blind", default=str(HERE / "blind"))
    ap.add_argument("--raters", type=int, default=5)
    ap.add_argument("--seed", type=int, default=None, help="fix for reproducibility (keep it secret)")
    args = ap.parse_args()

    samples = sorted(Path(args.out).glob("*/sample.wav"))
    if len(samples) < 2:
        raise SystemExit(f"need >= 2 outputs in {args.out}/*/sample.wav, found {len(samples)}")
    rng = random.Random(args.seed)
    rng.shuffle(samples)

    blind = Path(args.blind)
    if blind.exists():
        shutil.rmtree(blind)
    blind.mkdir(parents=True)

    key = {}
    for letter, src in zip(string.ascii_uppercase, samples):
        shutil.copyfile(src, blind / f"{letter}.wav")
        key[letter] = src.parent.name
    (blind / ".key.json").write_text(json.dumps(key, indent=2), encoding="utf-8")

    letters = list(key)
    with open(blind / "rating_sheet.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(COLUMNS)
        for r in range(1, args.raters + 1):
            order = letters[:]
            rng.shuffle(order)
            for i, letter in enumerate(order, 1):
                w.writerow([f"R{r}", i, letter, "", "", "", ""])

    print(f"{len(letters)} samples -> {blind}/ (key hidden in .key.json, sheet rating_sheet.csv)")


if __name__ == "__main__":
    main()
