#!/usr/bin/env bash
# Android TV banners from the app icon: the launcher banner (320×180, xhdpi)
# and the Play listing banner (1280×720). Needs ImageMagick 7 and
# ../CuteKidFonts next to the repo (the kid font used for titles).
set -euo pipefail
cd "$(dirname "$0")/.."

icon=app/assets/icon/icon_foreground.png
font=../CuteKidFonts/fonts/Baloo2-Variable.ttf
out=app/store/tv
mkdir -p "$out"

# Night sky like the icon, the icon's moon (transparent foreground) on the left, the name on the right.
magick -size 1280x720 radial-gradient:'#1F1B2E'-'#07070A' \
  \( "$icon" -resize 760x760 \) -gravity west -geometry -40+0 -composite \
  -font "$font" -fill '#E8CF9A' -pointsize 150 -strokewidth 3 -stroke "#E8CF9A" -gravity west -annotate +660+40 'Hajánek' \
  "$out/banner_1280x720.png"

magick "$out/banner_1280x720.png" -resize 320x180 \
  app/android/app/src/main/res/drawable-xhdpi/tv_banner.png

echo "wrote $out/banner_1280x720.png and res/drawable-xhdpi/tv_banner.png"
