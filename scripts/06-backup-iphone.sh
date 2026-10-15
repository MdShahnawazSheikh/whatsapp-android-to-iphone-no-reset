#!/bin/bash
# Full unencrypted backup of the iPhone into <dir>. Run once for a SAFETY copy before anything,
# and again (to a different dir) right after WhatsApp is registered on the iPhone, as the WORKING copy.
# usage: 06-backup-iphone.sh <dir>
set -euo pipefail
DIR="${1:?usage: $0 <dir>}"; mkdir -p "$DIR"
idevicepair validate
enc=$(ideviceinfo -q com.apple.mobile.backup -k WillEncrypt)
[[ "$enc" == "false" ]] || { echo "Backup encryption is ON. Turn it off in Finder (select iPhone > uncheck 'Encrypt local backup') or: idevicebackup2 encryption off <password>"; exit 1; }
idevicebackup2 backup --full "$DIR"
UD=$(ls -d "$DIR"/*/ | head -1)
sqlite3 "$UD/Manifest.db" "select 'WhatsApp files in backup', count(*) from Files where domain like '%whatsapp%';"
echo "backup: $UD ($(du -sh "$DIR" | cut -f1))"
