#!/bin/bash
# Downloads the WhatsApp .ipa matching the version installed on the iPhone and extracts the CoreData model.
# Run `ipatool auth login --email <apple id>` once first (interactive 2FA).
# usage: 04-get-ipa.sh [out_dir=./ipa]
set -euo pipefail
OUT="${1:-./ipa}"; mkdir -p "$OUT"
PHONE_VER=$(ideviceinstaller list --user 2>/dev/null | grep net.whatsapp.WhatsApp | cut -d'"' -f2 || true)
ipatool download -b net.whatsapp.WhatsApp --purchase -o "$OUT/WhatsApp.ipa" 2>&1 | tail -1
rm -rf "$OUT/app"; unzip -q "$OUT/WhatsApp.ipa" -d "$OUT/app"
IPA_VER=$(plutil -extract CFBundleShortVersionString raw "$OUT/app/Payload/WhatsApp.app/Info.plist")
MOMD=$(find "$OUT/app" -name WhatsAppChat.momd | head -1)
echo "ipa version: $IPA_VER   iPhone WhatsApp version: ${PHONE_VER:-unknown}"
[[ "$IPA_VER" == "$PHONE_VER" ]] || echo "WARNING: versions differ. Update WhatsApp on the iPhone (App Store) until they match."
echo "model: $MOMD"
