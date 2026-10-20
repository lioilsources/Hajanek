# TTS benchmark (ADR-001)

Generates the same ~1 min Czech sample (`sample_cs.md`) with each shortlisted
engine, measures RTF and prepares an anonymized blind listening test.
Decision context: `docs/adr/ADR-001-tts-engine.md`.

| Adapter | Engine | Licence | Notes |
|---|---|---|---|
| `dots` | dots.tts-soar | Apache-2.0 | 2B, GPU; speed via time-stretch |
| `moss` | MOSS-TTS v1.5 | Apache-2.0 | ~8.5B, GPU; speed via duration tokens |
| `pocket` | Pocket TTS Czech (community) | CC-BY-4.0 | CPU; speed via time-stretch |

## Layout

```
bench/
  sample_cs.md          script in CONTRACTS.md §2 markup
  run_bench.py          parser + runner -> out/{engine}/sample.wav, timing.json
  make_blind_sheet.py   out/*/sample.wav -> blind/A.wav… + .key.json + rating_sheet.csv
  engines/{dots,moss,pocket}.py
  refs/                 reference voice (not committed — personal data)
```

## 1. Reference voice

All engines clone the **same** reference, recorded with the speaker's written
consent (calm room, 48 kHz mono WAV, no music/reverb):

```
refs/ref.wav             10–15 s calm bedtime reading
refs/ref.txt             exact transcript of ref.wav
refs/ref.whisper.wav     5–10 s whispered reading (optional; used for [whisper])
refs/ref.whisper.txt     its transcript
```

Without `ref.whisper.wav` the runner falls back to a 3.5 kHz low-pass + −10 dB.

## 2. One uv venv per engine on the Spark

Engines pin conflicting `torch`/`transformers` versions, so each gets its own
venv. GB10 is aarch64 + CUDA 13: use the `cu130` PyTorch index
(aarch64 wheels exist at https://download.pytorch.org/whl/cu130/torch/).

```bash
cd forge/python/bench
TORCH_IDX=https://download.pytorch.org/whl/cu130
COMMON="numpy soundfile librosa"

# dots.tts
uv venv .venv-dots --python 3.10
VIRTUAL_ENV=.venv-dots uv pip install torch torchaudio --index-url $TORCH_IDX
VIRTUAL_ENV=.venv-dots uv pip install $COMMON "git+https://github.com/studio-dots-ai/dots.tts.git"

# MOSS-TTS v1.5 (repo pins torch 2.9.1+cu128 — install cu130 torch first, then the
# package without letting it replace torch)
uv venv .venv-moss --python 3.12
git clone https://github.com/OpenMOSS/MOSS-TTS.git ../.moss-src
VIRTUAL_ENV=.venv-moss uv pip install "torch==2.9.1" "torchaudio==2.9.1" --index-url $TORCH_IDX
VIRTUAL_ENV=.venv-moss uv pip install $COMMON -e ../.moss-src --no-deps
VIRTUAL_ENV=.venv-moss uv pip install "transformers==5.0.0"   # + remaining deps from its pyproject.toml

# Pocket TTS Czech (CPU is fine)
uv venv .venv-pocket --python 3.12
VIRTUAL_ENV=.venv-pocket uv pip install $COMMON pocket-tts
```

Verify the GPU is visible before running: 
`.venv-dots/bin/python -c "import torch; print(torch.cuda.get_device_name(), torch.cuda.get_device_capability())"`
(expect GB10, `(12, 1)`). FlashAttention is optional; adapters use SDPA.

## 3. Run

```bash
.venv-dots/bin/python   run_bench.py --engine dots   --ref refs/ref.wav
.venv-moss/bin/python   run_bench.py --engine moss   --ref refs/ref.wav
.venv-pocket/bin/python run_bench.py --engine pocket --ref refs/ref.wav
```

Each run writes `out/{engine}/sample.wav` and `out/{engine}/timing.json`
(`rtf` = synthesis time / generated voice time, model load excluded).

Env overrides: `DOTS_MODEL` (e.g. `dots-studio/dots.tts-mf` for speed),
`DOTS_COMPILE=1` (torch.compile), `MOSS_MODEL`, `POCKET_CONFIG`,
`POCKET_DEVICE=cuda`.

## 4. Loudness-match, then blind sheet

Normalize to −23 LUFS so the louder engine doesn't win (in place):

```bash
for f in out/*/sample.wav; do
  ffmpeg -y -loglevel error -i "$f" -af loudnorm=I=-23:TP=-3 -ar 48000 "${f%.wav}.norm.wav" \
    && mv "${f%.wav}.norm.wav" "$f"
done
python3 make_blind_sheet.py --raters 5
```

Share only `blind/*.wav` and `blind/rating_sheet.csv` with raters; keep
`blind/.key.json` closed until all sheets are back. Procedure and scoring:
ADR-001 §7.

## Adding an engine

Create `engines/<name>.py` with `class Engine` (see `engines/__init__.py`):
`__init__(ref_wav)`, `synth(text, speed, style) -> (np.ndarray, sr)`,
flags `native_speed` / `native_whisper`. Import the engine's package inside
`__init__` so other venvs don't need it.
