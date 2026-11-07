#!/usr/bin/env bash
# Android TV banners from the app icon: the launcher banner (320×180, xhdpi),
# the Play TV banner (1280×720) and the Play feature graphic (1024×500). Needs ImageMagick 7 and
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

# Feature graphic: same picture, with the tagline under the name.
magick -size 1024x500 radial-gradient:'#1F1B2E'-'#07070A' \
  \( "$icon" -resize 560x560 \) -gravity west -geometry -40+0 -composite \
  -font "$font" -fill '#E8CF9A' -pointsize 120 -strokewidth 2 -stroke '#E8CF9A' -gravity west -annotate +470-20 'Hajánek' \
  -font "$font" -fill '#B8A88A' -stroke none -pointsize 40 -gravity west -annotate +478+75 'Usínací pohádky a zvuky' \
  app/store/feature_1024x500.png

echo "wrote $out/banner_1280x720.png, res/drawable-xhdpi/tv_banner.png and app/store/feature_1024x500.png"
