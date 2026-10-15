# How it works: the technical details

Everything below was reverse-engineered in October 2026 against WhatsApp Android 2.25.x (Android 15)
and WhatsApp iOS 26.40.77 (iOS 27.0.1). Column names and magic numbers may drift with future versions;
the scripts print counts and run `integrity_check` at every step so drift shows up as numbers, not silence.

## 1. Getting a decrypted `msgstore.db` without root

WhatsApp Android keeps the live database in private app storage (`/data/data/com.whatsapp`), unreachable
without root. The **local backup** in `/sdcard/Android/media/com.whatsapp/WhatsApp/Databases/` is readable,
but encrypted:

| File | Key |
|---|---|
| `msgstore.db.crypt14` | per-install key in private storage (root needed) |
| `msgstore.db.crypt15` | the **end-to-end encrypted backup key** |

When you enable *End-to-end encrypted backup* and choose the **64-digit key** option, WhatsApp re-creates the
local backup as `crypt15`, encrypted with a key **you** hold. `wadecrypt <64-hex-key> msgstore.db.crypt15 msgstore.db`
(from wa-crypt-tools) gives a plain SQLite file. No root, no APK downgrade.

Note: `adb pull` of this 250 MB file repeatedly stalled and dropped the device over a USB hub on a OPPO phone.
Wireless debugging (`adb mdns services` shows it; it auto-connects) was reliable at ~18 MB/s.

## 2. The modern Android schema vs what watoi expects

watoi (2017–2021) reads three things from `msgstore.db`:

```sql
SELECT * FROM chat_view                                     -- raw_string_jid, subject, archived, created_timestamp
SELECT * FROM messages WHERE key_remote_jid = ? AND status != 6 ORDER BY timestamp
       -- key_from_me, key_id, timestamp, media_wa_type, data, media_caption, remote_resource
SELECT * FROM group_participants WHERE gjid = ?             -- jid, admin
```

None of those exist in the modern schema (the `chat_view` view exists but has no JID column). The modern tables:

* `chat(_id, jid_row_id, subject, archived, created_timestamp, last_message_row_id, account_jid_row_id, …)`
* `message(_id, chat_row_id, from_me, key_id, sender_jid_row_id, status, timestamp, message_type, text_data, starred, …)`
* `message_media(message_row_id, file_path, file_size, media_caption, mime_type, …)`
* `jid(_id, user, server, type, raw_string)` and `jid_map(lid_row_id, jid_row_id)`
* `group_participant_user(group_jid_row_id, user_jid_row_id, rank, …)`
* `message_event`, `message_poll`, `message_view_once_media`, `message_album`, …

`shim.sql` builds the three legacy tables on a **copy** of the DB.

### LID (hidden-number) JIDs

Since 2024 WhatsApp assigns every account a *LID* (`<number>@lid`) alongside the phone JID
(`<phone>@s.whatsapp.net`). Some chats and many group senders are stored by LID. `jid_map` maps LID→phone.
The shim resolves every JID through that map, so chats and senders come out as phone JIDs, which is what the
iPhone's address book can name. In our data all 74 LID chats resolved and none collided with an existing
phone-JID chat. Unresolvable LIDs are excluded (count is printed).

The account owner appears in `jid` as `lid_me` / `status_me` / `0@s.whatsapp.net`; those rows are excluded
from participants so watoi never sees an empty "me" JID (its original crash).

### Message types

| Android `message_type` | Meaning | What we do |
|---|---|---|
| 0 | text | import |
| 1,2,3,4,5,9,13,14,15,16,20 | image, audio, video, contact, location, document, gif, contacts, **revoked**, live location, sticker | same legacy code; watoi writes a `<image>`/`<sticker>`… placeholder plus caption |
| 42, 43 | view-once image / video | map to 1 / 3 |
| 66, 109 | poll | text `POLL: <question>` |
| 92 | event | text `EVENT: <name> - <description>` (from `message_event`) |
| 24, 25, 28, 42, 49, 57 … | business/template/link messages that carry `text_data` | text |
| 7 | system notice ("X joined") | skip (`status=6`) |
| 10 | missed call | skip |
| 90 | placeholder / unsupported | skip |
| 99 | album container (its photos are separate rows) | skip |
| anything else with `text_data IS NULL` | unknown | skip, counted |

Captions: modern Android stores media captions in `message.text_data` (and sometimes `message_media.media_caption`);
the shim exposes both as `media_caption`.

## 3. The iOS side: `ChatStorage.sqlite`

iOS WhatsApp stores chats in a CoreData SQLite store in the app group container
`group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite`. In an **unencrypted** iTunes/Finder backup it is the file

```
fileID = sha1("AppDomainGroup-group.net.whatsapp.WhatsApp.shared-ChatStorage.sqlite")
       = 7c7fba66680ef796b916b067077cc246adacf01d        (same on every device)
```
stored at `<backup>/7c/7c7fba66…`, catalogued in `Manifest.db` (`Files` table).

watoi opens the store through the **real CoreData model** (`WhatsAppChat.momd` inside the `.ipa`, at
`Frameworks/SharedModules.framework/` in current builds; older guides say `Core.framework`). That means it
never has to know the column layout; CoreData writes `ZWACHATSESSION`, `ZWAMESSAGE`, `ZWAGROUPMEMBER`,
`ZWAGROUPINFO` and the `Z_PRIMARYKEY` bookkeeping correctly for whatever version you have.

**The iPhone must already be registered** with the number so the store exists and group metadata has synced.

### Why `post.sh` exists

Comparing watoi's rows with rows WhatsApp wrote itself showed several gaps. Earlier users saw an *empty
chat list* after restore and needed an iCloud backup/reinstall round-trip to fix it. The cause is the first row:

| Field | watoi | WhatsApp itself | fix |
|---|---|---|---|
| `ZWACHATSESSION.ZLASTMESSAGE`, `ZLASTMESSAGEDATE` | NULL on every new chat (a loop-variable bug: `for (msg in newMessages)` leaves `msg` nil) | set | point at the highest `ZSORT` message |
| `ZSESSIONTYPE` | 0 for groups | 1 for groups, 0 for 1:1 | set |
| `ZFLAGS` (session) | 0 | 256 | set |
| `ZWAMESSAGE.ZMESSAGESTATUS` | 0 incoming / 5 outgoing | 8 (read) | 8 |
| `ZFLAGS` (message) | 0 | 16777216 incoming, 16777280 outgoing | set |
| `ZDATAITEMVERSION` | 2 | 3 | 3 |
| `ZSENTDATE` | NULL | set | = `ZMESSAGEDATE` |
| `ZWAGROUPMEMBER.ZISACTIVE` | 0 | 1 for current members | 1 when present in `group_participants` |
| `ZSTARRED` | — | 1 | carried from Android `message.starred` |

With these, chats appeared immediately after restore. No iCloud round-trip was needed.

### Journal mode

The on-device store is in WAL mode; WhatsApp checkpoints before backup so no `-wal` file is in the backup.
watoi switches the file to `DELETE` mode; the pipeline switches it back to `wal` (which leaves no side files)
so it matches the original.

## 4. Stickers

A sticker on iOS is a `ZWAMESSAGE` with `ZMESSAGETYPE = 15`, `ZTEXT = NULL`, linked to a `ZWAMEDIAITEM`:

```
ZMEDIALOCALPATH = Media/<chat jid>/<x>/<y>/<uuid>.webp      (x, y = first two chars of the uuid)
ZFILESIZE, ZVCARDSTRING = 'image/webp', ZVCARDNAME = base64(sha256(file))
ZMEDIAORIGIN = 0, ZMOVIEDURATION = 0, lat/long/accuracy/aspect = 0.0
```
Real rows also carry `ZMEDIAURL`, `ZMEDIAKEY`, `ZMETADATA` (a protobuf). We leave those NULL; the sticker renders
from the local file. Message flags: `83886080` incoming, `16781376` outgoing (observed).

The file lives in the backup at `Message/Media/<chat jid>/<x>/<y>/<uuid>.webp` inside the same app-group domain.
Each file (and each directory level) needs a `Files` row in `Manifest.db` whose `file` column is an
NSKeyedArchiver-encoded `MBFile`:

```
$objects = ["$null",
            {$class: UID(4), Birth, LastModified, LastStatusChange, Flags: 0, GroupID: 501, UserID: 501,
             InodeNumber: <unique>, Mode: 33188 (file) | 16877 (dir), ProtectionClass: 3 (file) | 0 (dir),
             RelativePath: UID(2), Size, ExtendedAttributes: UID(3)},
            "<relativePath>",
            <bplist {"com.whatsapp.original": b"Media/<…>.webp"}>,      (files only)
            {$classname: "MBFile", $classes: ["MBFile","NSObject"]}]
```
`flags` column: 1 = file, 2 = directory. `sticker_inject.py` builds these from scratch; `fileID` is
`sha1(domain + "-" + relativePath)`. One copy per (chat, sticker) keeps size sane (2,247 files / 286 MB
for 23,766 sticker messages).

Only stickers whose `.webp` is still in `/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Stickers/`
can be carried; WhatsApp prunes old ones (44 % were still present in our case).

Photos/videos could be done the same way (`ZMESSAGETYPE` 1/2, `.jpg`/`.mp4`, probably plus a `.thumb`),
but were out of scope.

## 5. Backup and restore without Finder

`idevicebackup2 backup --full <dir>` and `idevicebackup2 restore --system --settings --reboot <dir>` talk to the
device's `mobilebackup2` service directly. After swapping `ChatStorage.sqlite`, the `Size` in its `MBFile`
plist must be updated or the restore fails. No digest is checked.

The device refuses `restore` with `MBErrorDomain/211` while **Find My iPhone** is on. The refusal happens
before any data is touched. Restoring the backup you took minutes earlier is not a reset: iOS lays the
backup's files back down, and the only content that differs is WhatsApp's.

## 6. Numbers from the reference run

| | Android | Imported |
|---|---|---|
| messages | 524,105 | 471,555 |
| chats with messages | 810 | 656 (67 groups) |
| sticker messages | 53,958 | 23,766 with real files, rest placeholders |
| starred | 73 | 72 |

The ~52k not imported: 41k "joined/left" system notices, 5.2k placeholders, 1.2k missed-call rows,
2.6k channel posts, 300 album containers, 420 broadcast-list copies, ~2k unknown non-text items.
