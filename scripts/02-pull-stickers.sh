#!/bin/bash
# Copies the sticker files still present on the Android phone. Only these can be carried over.
# usage: 02-pull-stickers.sh [out_dir=./stickers]
set -euo pipefail
OUT="${1:-./stickers}"; mkdir -p "$OUT"
n=$(adb devices | grep -c "device$" || true)
ADB="adb"; [[ $n -gt 1 ]] && ADB="adb -s $(adb devices | grep 'device$' | grep -m1 ':' | cut -f1)"
$ADB pull "/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Stickers" "$OUT/"
$ADB pull "/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Business Stickers" "$OUT/" 2>/dev/null || true
echo "sticker files: $(find "$OUT" -name '*.webp' | wc -l)"
