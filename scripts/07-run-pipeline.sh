#!/bin/bash
# Converts the Android chats into the iPhone's WhatsApp database inside the WORKING backup.
# usage: 07-run-pipeline.sh <working_backup_root> <msgstore_shim.db> <WhatsAppChat.momd> <watoi_binary> [stickers_dir]
set -euo pipefail
ROOT="${1:?}"; SHIM="${2:?}"; MOMD="${3:?}"; WATOI="${4:?}"; STK="${5:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
B=$(ls -d "$ROOT"/*/ | head -1); B="${B%/}"
CID=7c7fba66680ef796b916b067077cc246adacf01d   # sha1("AppDomainGroup-group.net.whatsapp.WhatsApp.shared-ChatStorage.sqlite"), same for everyone
test -f "$B/Manifest.db" && test -f "$B/7c/$CID" || { echo "backup incomplete or WhatsApp not in it (is WhatsApp registered on the iPhone?)"; exit 1; }
RUN="$ROOT/.run"; rm -rf "$RUN"; mkdir -p "$RUN"
cp "$B/7c/$CID" "$RUN/ChatStorage.orig.sqlite"; cp "$B/7c/$CID" "$RUN/ChatStorage.sqlite"; cp "$B/Manifest.db" "$RUN/Manifest.orig.db"
S=$(sqlite3 "$RUN/ChatStorage.sqlite" "select Z_MAX from Z_PRIMARYKEY where Z_NAME='WAChatSession'")
M=$(sqlite3 "$RUN/ChatStorage.sqlite" "select Z_MAX from Z_PRIMARYKEY where Z_NAME='WAMessage'")
G=$(sqlite3 "$RUN/ChatStorage.sqlite" "select Z_MAX from Z_PRIMARYKEY where Z_NAME='WAGroupMember'")
echo "baseline: sessions=$S messages=$M members=$G"
sqlite3 "$RUN/ChatStorage.sqlite" "select 'before: chats', count(*) from ZWACHATSESSION; select 'before: messages', count(*) from ZWAMESSAGE;"
"$WATOI" "$SHIM" "$RUN/ChatStorage.sqlite" "$MOMD" > "$RUN/watoi.log" 2>&1 || { echo "watoi FAILED:"; tail -20 "$RUN/watoi.log"; exit 1; }
echo "watoi error lines: $(grep -ciE 'exception|abort|error' "$RUN/watoi.log" || true)   (log: $RUN/watoi.log)"
"$HERE/post.sh" "$RUN/ChatStorage.sqlite" "$SHIM" "$S" "$M" "$G"
rm -f "$RUN/ChatStorage.sqlite-shm" "$RUN/ChatStorage.sqlite-wal"
if [[ -n "$STK" ]]; then python3 -I "$HERE/sticker_inject.py" "$RUN/ChatStorage.sqlite" "$SHIM" "$STK" "$B" "$M"; fi
sqlite3 "$RUN/ChatStorage.sqlite" "pragma integrity_check; select 'after: chats', count(*) from ZWACHATSESSION; select 'after: messages', count(*) from ZWAMESSAGE; select 'after: stickers', count(*) from ZWAMESSAGE where ZMESSAGETYPE=15; select 'after: starred', count(*) from ZWAMESSAGE where ZSTARRED=1; select 'chats without last message', count(*) from ZWACHATSESSION where ZLASTMESSAGE is null;"
sqlite3 "$RUN/ChatStorage.sqlite" "pragma journal_mode=wal;" >/dev/null; rm -f "$RUN/ChatStorage.sqlite-wal" "$RUN/ChatStorage.sqlite-shm"
cp "$RUN/ChatStorage.sqlite" "$B/7c/$CID"
SIZE=$(stat -f%z "$B/7c/$CID")
python3 -I - "$B/Manifest.db" "$CID" "$SIZE" <<'PY'
import sys, sqlite3, plistlib
db, fid, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
c = sqlite3.connect(db)
d = plistlib.loads(c.execute("select file from Files where fileID=?", (fid,)).fetchone()[0])
d['$objects'][1]['Size'] = size
c.execute("update Files set file=? where fileID=?", (plistlib.dumps(d, fmt=plistlib.FMT_BINARY), fid)); c.commit()
print("Manifest.db size updated:", size, d['$objects'][2])
PY
echo "PIPELINE DONE -> now run 08-restore-iphone.sh $ROOT"
