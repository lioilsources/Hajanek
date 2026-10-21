#!/usr/bin/env bash
# Copy the published catalog (hajanek-content) into the app bundle, so the app
# ships exactly what Pages serves, plus the voice recording text. Run after
# `forge publish`.
#
#   tools/sync_app_bundle.sh [PAGES_DIR]   # default ../hajanek-content
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PAGES=${1:-$ROOT/../hajanek-content}
A=$ROOT/app/assets
python3 -I - "$PAGES" "$A" <<'PY'
import hashlib, json, os, shutil, sys
pages, assets = sys.argv[1:]
cat = json.load(open(os.path.join(pages, "catalog.json")))
files = [s for t in cat["tales"] for s in t["scripts"]] + cat["ambient"]
want = {f["path"] for f in files}
for f in files:
    src, dst = os.path.join(pages, f["path"]), os.path.join(assets, f["path"])
    b = open(src, "rb").read()
    if hashlib.sha256(b).hexdigest() != f["sha256"]:
        sys.exit(f"{f['path']}: sha256 does not match catalog.json")
    if not os.path.exists(dst) or open(dst, "rb").read() != b:
        shutil.copyfile(src, dst)
        print("copied", f["path"])
for d in ("scripts", "ambient"):
    for n in sorted(os.listdir(os.path.join(assets, d))):
        if f"{d}/{n}" not in want:
            os.remove(os.path.join(assets, d, n))
            print("removed", f"{d}/{n}")
shutil.copyfile(os.path.join(pages, "catalog.json"), os.path.join(assets, "catalog", "catalog.json"))
shutil.copyfile(os.path.join(os.path.dirname(assets), "..", "content", "voice", "recording_script.md"),
                os.path.join(assets, "voice", "recording_script.md"))
print(f"app bundle = catalog v{cat['version']}: {len(cat['tales'])} tales, {len(cat['ambient'])} ambient")
PY
