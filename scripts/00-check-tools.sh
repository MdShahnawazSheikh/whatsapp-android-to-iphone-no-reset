#!/bin/bash
# Verifies every tool the pipeline needs is present on this Mac.
ok=1
for t in adb xcodebuild sqlite3 python3 idevicebackup2 ideviceinfo ideviceinstaller ipatool; do
  if command -v $t >/dev/null; then echo "ok   $t"; else echo "MISSING $t"; ok=0; fi
done
python3 -c "import wa_crypt_tools" 2>/dev/null && echo "ok   wa-crypt-tools" || { echo "MISSING wa-crypt-tools (pip install wa-crypt-tools)"; ok=0; }
echo
echo "Install missing pieces with:"
echo "  brew install libimobiledevice ideviceinstaller ipatool android-platform-tools"
echo "  pip3 install wa-crypt-tools      (or use a venv)"
echo "  Xcode from the App Store (full Xcode, not just the CLI tools)"
[ $ok = 1 ] && echo "All tools present."
