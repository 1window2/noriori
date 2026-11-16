#!/bin/bash
# 앱 아이콘을 apps/noriori/icon/의 SVG에서 만든다. 쓰는 법: gen_icons.sh [front]. rsvg-convert가 필요하다 (brew install librsvg)
# Android는 적응형 아이콘(배경색 + 앞그림)과 옛 기기용 PNG, iOS는 AppIcon 세트의 모든 크기를 다시 쓴다
set -eo pipefail
cd "$(dirname "$0")/.."
name=${1:-front}
src=apps/noriori/icon
[ -f "$src/$name.svg" ] || { echo "$src/$name.svg가 없습니다"; exit 1; }
bg=$(cat "$src/$name.background")
res=apps/noriori/android/app/src/main/res
for d in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  n=${d%%:*}; s=${d##*:}
  px=$(python3 -c "print(round(48*$s))"); fpx=$(python3 -c "print(round(108*$s))")
  rsvg-convert -w "$px" -h "$px" "$src/$name.svg" -o "$res/mipmap-$n/ic_launcher.png"
  rsvg-convert -w "$fpx" -h "$fpx" "$src/$name-foreground.svg" -o "$res/mipmap-$n/ic_launcher_foreground.png"
done
mkdir -p "$res/mipmap-anydpi-v26"
cat > "$res/mipmap-anydpi-v26/ic_launcher.xml" <<X
<?xml version="1.0" encoding="utf-8"?>
<!-- tools/gen_icons.sh가 만든다. 앞그림은 가운데 66dp 안에 있어 원형 마스크에서도 잘리지 않는다 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
X
cat > "$res/values/ic_launcher_background.xml" <<X
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">$bg</color>
</resources>
X
# iOS 아이콘은 투명도가 없어야 한다. BMP를 거쳐 알파 채널을 뺀다
set_dir=apps/noriori/ios/Runner/Assets.xcassets/AppIcon.appiconset
tmp=$(mktemp -d)
python3 - "$set_dir/Contents.json" <<'P' | while read -r file px; do
import json,sys
for x in json.load(open(sys.argv[1]))['images']:
    w=float(x['size'].split('x')[0])*int(x['scale'][0])
    print(x['filename'],round(w))
P
  rsvg-convert -w "$px" -h "$px" -b "$bg" "$src/$name.svg" -o "$tmp/a.png"
  sips -s format bmp "$tmp/a.png" --out "$tmp/a.bmp" >/dev/null
  sips -s format png "$tmp/a.bmp" --out "$set_dir/$file" >/dev/null
done
rm -rf "$tmp"
echo "아이콘 $name, 배경 $bg"
