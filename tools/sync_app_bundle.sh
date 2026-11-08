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
import glob, hashlib, json, os, shutil, sys
pages, assets = sys.argv[1:]
# catalog.json is Czech; every other language is i18n/{lang}/catalog.json (docs/I18N_PLAN.md).
catalogs = {"cs": "catalog.json"}
for p in sorted(glob.glob(os.path.join(pages, "i18n", "*", "catalog.json"))):
    catalogs[os.path.basename(os.path.dirname(p))] = os.path.relpath(p, pages)
want, dirs = set(), {"scripts", "ambient"}
for lang, rel in catalogs.items():
    cat = json.load(open(os.path.join(pages, rel)))
    files = [s for t in cat["tales"] for s in t["scripts"]] + cat["ambient"]
    for f in files:
        want.add(f["path"])
        dirs.add(os.path.dirname(f["path"]))
        src, dst = os.path.join(pages, f["path"]), os.path.join(assets, f["path"])
        b = open(src, "rb").read()
        if hashlib.sha256(b).hexdigest() != f["sha256"]:
            sys.exit(f"{f['path']}: sha256 does not match {rel}")
        if not os.path.exists(dst) or open(dst, "rb").read() != b:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copyfile(src, dst)
            print("copied", f["path"])
    dst = os.path.join(assets, "catalog", "catalog.json") if lang == "cs" else os.path.join(assets, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(os.path.join(pages, rel), dst)
    print(f"{lang}: catalog v{cat['version']}: {len(cat['tales'])} tales, {len(cat['ambient'])} ambient")
for d in sorted(dirs):
    for n in sorted(os.listdir(os.path.join(assets, d))):
        if f"{d}/{n}" not in want and n != "catalog.json":
            os.remove(os.path.join(assets, d, n))
            print("removed", f"{d}/{n}")
shutil.copyfile(os.path.join(os.path.dirname(assets), "..", "content", "voice", "recording_script.md"),
                os.path.join(assets, "voice", "recording_script.md"))
PY
