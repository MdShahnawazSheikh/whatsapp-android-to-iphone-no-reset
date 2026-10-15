#!/bin/bash
# Creates msgstore_shim.db: a copy of the decrypted Android DB plus the legacy-schema tables watoi needs.
# usage: 03-build-shim.sh <msgstore.db> [stickers_dir] [out=msgstore_shim.db]
set -euo pipefail
SRC="${1:?usage: $0 <msgstore.db> [stickers_dir] [out]}"; STK="${2:-}"; OUT="${3:-$(dirname "$SRC")/msgstore_shim.db}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cp "$SRC" "$OUT"
sqlite3 "$OUT" < "$HERE/shim.sql"
sqlite3 "$OUT" "drop table if exists sticker_present; create table sticker_present(file_path text primary key);"
if [[ -n "$STK" && -d "$STK" ]]; then
  find "$STK" -type f -exec basename {} \; | sort -u | awk '{print "insert or ignore into sticker_present values(\x27Media/WhatsApp Stickers/" $0 "\x27); insert or ignore into sticker_present values(\x27Media/WhatsApp Business Stickers/" $0 "\x27);"}' | sqlite3 "$OUT"
fi
sqlite3 "$OUT" "
select 'chats to import', count(*) from chat_view;
select 'groups', count(*) from chat_view where subject is not null;
select 'messages to import', count(*) from messages where status<>6;
select 'messages skipped (system/calls/unsupported)', count(*) from messages where status=6;
select 'sticker messages with file available', count(*) from messages ms join message_media mm on mm.message_row_id=ms._id join sticker_present sp on sp.file_path=mm.file_path where ms.orig_type=20 and ms.status<>6;
select 'starred', count(*) from starred_keys;"
echo "shim: $OUT"
