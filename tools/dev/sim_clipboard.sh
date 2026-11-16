#!/bin/bash
# 맥 클립보드를 켜 둔 iOS 시뮬레이터 클립보드로 계속 넘긴다. 끝내려면 Ctrl+C
# 시뮬레이터 패널은 맥 입력기가 조합한 한글·가나를 넘기지 못하고 영문 글자만 넘긴다(dnpsh가 그대로 들어감).
# 맥에서 한국어·일본어로 쳐서 복사(⌘C)한 뒤 시뮬레이터 입력란을 길게 눌러 붙여넣기 한다
last=''
while sleep 0.5; do
  now=$(pbpaste 2>/dev/null)
  if [ "$now" != "$last" ]; then
    printf '%s' "$now" | LANG=en_US.UTF-8 xcrun simctl pbcopy booted && last=$now
  fi
done
