#!/usr/bin/env python3
"""TTS worker: JSON lines over stdin/stdout.

request:  {"text", "speed", "style", "voice_ref", "out_path"}
response: {"ok", "duration_s", "style_applied", "error"?}
Logs go to stderr; stdout carries only responses.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import engines  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--engine", default=os.environ.get("FORGE_TTS_ENGINE", "dummy"))
    args = ap.parse_args()
    out = sys.stdout
    try:
        engine = engines.load(args.engine)
    except Exception as e:  # report on first request so the caller sees the reason
        print(f"tts_worker: cannot load engine {args.engine}: {e}", file=sys.stderr)
        for line in sys.stdin:
            if line.strip():
                out.write(json.dumps({"ok": False, "error": f"engine {args.engine}: {e}"}) + "\n")
                out.flush()
        return 1
    print(f"tts_worker: engine={args.engine} ready", file=sys.stderr)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            os.makedirs(os.path.dirname(os.path.abspath(req["out_path"])), exist_ok=True)
            tmp = req["out_path"] + ".part.wav"
            res = engine.synthesize(req["text"], float(req.get("speed") or 1.0),
                                    req.get("style") or "soft", req.get("voice_ref"), tmp)
            os.replace(tmp, req["out_path"])
            resp = {"ok": True, "duration_s": round(res.duration_s, 3),
                    "style_applied": bool(res.style_applied)}
        except Exception as e:
            traceback.print_exc(file=sys.stderr)
            resp = {"ok": False, "error": f"{type(e).__name__}: {e}"}
        out.write(json.dumps(resp, ensure_ascii=False) + "\n")
        out.flush()
    engine.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
