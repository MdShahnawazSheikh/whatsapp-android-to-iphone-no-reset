#!/bin/bash
# Pulls the end-to-end-encrypted local backup (msgstore.db.crypt15) from the Android phone over adb
# and decrypts it with the 64-digit key WhatsApp showed you.
# usage: 01-pull-android.sh <64-hex-key> [out_dir=./android]
set -euo pipefail
KEY="${1:?usage: $0 <64-hex-key> [out_dir]}"; OUT="${2:-./android}"
[[ ${#KEY} -eq 64 ]] || { echo "key must be 64 hex characters (remove spaces)"; exit 1; }
mkdir -p "$OUT"
SRC="/sdcard/Android/media/com.whatsapp/WhatsApp/Databases/msgstore.db.crypt15"
echo "devices:"; adb devices -l | tail -n +2
n=$(adb devices | grep -c "device$" || true)
[[ $n -ge 1 ]] || { echo "no adb device. Enable USB debugging, or Wireless debugging (adb auto-discovers it)."; exit 1; }
ADB="adb"; [[ $n -gt 1 ]] && ADB="adb -s $(adb devices | grep 'device$' | grep -m1 ':' | cut -f1)"
$ADB shell "ls -la $SRC" || { echo "no crypt15 backup on phone. In WhatsApp: Settings > Chats > Chat backup > End-to-end encrypted backup > Turn on (64-digit key) > then tap Back up."; exit 1; }
REMOTE_MD5=$($ADB shell "md5sum $SRC" | cut -d' ' -f1)
$ADB pull "$SRC" "$OUT/msgstore.db.crypt15"
LOCAL_MD5=$(md5 -q "$OUT/msgstore.db.crypt15")
[[ "$REMOTE_MD5" == "$LOCAL_MD5" ]] || { echo "checksum mismatch, pull was corrupted (USB hub? try Wi-Fi debugging)"; exit 1; }
echo "checksum ok"
wadecrypt "$KEY" "$OUT/msgstore.db.crypt15" "$OUT/msgstore.db"
sqlite3 "$OUT/msgstore.db" "select 'messages', count(*) from message; select 'chats with messages', count(*) from chat where last_message_row_id>0;"
echo "decrypted: $OUT/msgstore.db"
