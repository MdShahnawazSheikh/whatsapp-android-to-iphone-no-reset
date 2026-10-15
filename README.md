# WhatsApp: Android → iPhone, without resetting the iPhone

Move your **entire WhatsApp chat history** from an Android phone to an **already set-up iPhone**,
with free, open-source tools, **no factory reset, no root, no paid "transfer" apps**.

Text messages, groups and members, group names, timestamps, captions, starred messages,
polls and events (as text), deleted-message markers, and **stickers** (the ones still on the Android).
Photos, videos, voice notes and documents become `<image>` / `<video>` style placeholders
with their captions kept.

Proven in October 2026 on a OPPO (Android 15) → iPhone 17 (iOS 27.0.1, WhatsApp 26.40.77):
**524,105 messages, 656 chats, 67 groups, 23,766 stickers**, done in under a minute of
processing plus one iPhone reboot.

> **This whole thing was done by an AI agent (Claude Code) driving a Mac, with a human
> tapping on the phones.** If you'd rather not run the steps yourself, point your AI agent
> at [`docs/AI-AGENT-PROMPT.md`](docs/AI-AGENT-PROMPT.md) and let it drive.

---

## Why this exists

The only official route is Apple's **Move to iOS**, and it works **only during iPhone setup**.
If your iPhone is already in use you are told to erase it. Every "no reset" alternative on the
internet is a paid Windows/Mac app (MobileTrans, iCareFone, Dr.Fone…) that does, under the
hood, exactly what this repo does: pull the Android database, convert it, and inject it into an
iPhone backup. This repo is that process, open, documented, and reproducible.

## How it works (30-second version)

```
Android                         Mac                                      iPhone
───────                         ───                                      ──────
WhatsApp E2E backup  ──adb──▶  msgstore.db.crypt15
(64-digit key)                   │ wadecrypt (wa-crypt-tools)
                                 ▼
                              msgstore.db  ──shim.sql──▶  msgstore_shim.db   (legacy schema for watoi)
                                                               │
                              iPhone backup (idevicebackup2)   │        ◀──backup──  WhatsApp registered,
                                 │ ChatStorage.sqlite          │                     empty chat list
                                 ▼                             ▼
                              watoi (CoreData importer) + post.sh fix-ups + sticker_inject.py
                                 │
                                 ▼
                              modified backup  ────idevicebackup2 restore────▶  all chats appear
```

1. **Android side, no root.** Turn on *end-to-end encrypted backup* with a **64-digit key**.
   The local backup file becomes `crypt15`, which [wa-crypt-tools](https://github.com/ElDavoo/wa-crypt-tools)
   can decrypt with that key. (Older guides needed root or a downgraded APK. Not any more.)
2. **Schema shim.** Modern Android WhatsApp (2024+) uses a completely different schema than the
   open-source importer [watoi](https://github.com/residentsummer/watoi) expects. `shim.sql`
   rebuilds the legacy `chat_view` / `messages` / `group_participants` tables on a copy of the DB,
   resolves hidden-number (`@lid`) JIDs to phone JIDs, and maps modern message types.
3. **Import into the iPhone database.** `watoi` writes into `ChatStorage.sqlite` through WhatsApp's own
   CoreData model (extracted from the `.ipa`), so the iOS schema is always right for your exact version.
4. **Fix-ups.** `post.sh` sets everything watoi leaves blank that WhatsApp needs to show the chats
   (last-message pointers, group session type, flags, read status, starred, active members).
5. **Stickers.** `sticker_inject.py` copies the `.webp` files into the backup, writes the backup
   catalog (`Manifest.db`) entries, and links them as real sticker messages.
6. **Inject and restore.** The modified `ChatStorage.sqlite` goes back into the backup, and
   `idevicebackup2 restore` writes it to the phone. The phone is **not erased**: the backup was
   taken minutes earlier, so the only thing that changes is WhatsApp's data.

Full technical write-up: [`docs/HOW-IT-WORKS.md`](docs/HOW-IT-WORKS.md).

## Requirements

* A **Mac** with full **Xcode** installed (to build watoi against Apple's CoreData).
* Homebrew: `brew install libimobiledevice ideviceinstaller ipatool android-platform-tools`
* Python 3: `pip3 install wa-crypt-tools`
* An **Apple ID** (to download the WhatsApp `.ipa` with `ipatool`; the app is free).
* Android: USB debugging **or** Wireless debugging. iPhone: USB cable, "Trust this computer".
* iPhone backup encryption **off** (Finder → your iPhone → untick *Encrypt local backup*).
  Check that **iCloud Keychain** and **Health** sync are on, so nothing is lost by restoring an
  unencrypted backup (see [Safety](#safety)).

## Step by step

All scripts live in [`scripts/`](scripts) and are numbered in order. Run `scripts/00-check-tools.sh` first.

### 1. Android: make an E2E-encrypted backup and pull it
In WhatsApp on Android: **Settings → Chats → Chat backup → End-to-end encrypted backup → Turn on →
"Use 64-digit encryption key instead"**. Save the key. Then tap **Back up**.

```bash
scripts/01-pull-android.sh <64-digit-key-without-spaces>    # → android/msgstore.db
scripts/02-pull-stickers.sh                                   # → stickers/  (optional)
scripts/03-build-shim.sh android/msgstore.db stickers         # → android/msgstore_shim.db + import counts
```
If `adb pull` stalls or the phone keeps disconnecting, use **Wireless debugging** (Developer
options). `adb` discovers it automatically on the same Wi-Fi; no pairing needed if USB debugging
was already authorised.

### 2. Mac: get the WhatsApp .ipa and build the importer
```bash
ipatool auth login --email you@example.com      # once, interactive 2FA
scripts/04-get-ipa.sh                           # → ipa/app/.../WhatsAppChat.momd
scripts/05-build-watoi.sh                       # → watoi-src/build/Release/watoi
```
The `.ipa` version **must match** the WhatsApp version on the iPhone. Update the iPhone's
WhatsApp from the App Store if they differ.

### 3. iPhone: safety backup, register, working backup
```bash
scripts/06-backup-iphone.sh backups/safety      # full copy of the phone BEFORE anything changes
```
Now **register WhatsApp on the iPhone** with the same number. Skip *Restore from iCloud* and
*Transfer from Android*. Stop at the empty chat list. (This logs the Android out; its chats stay
on it untouched.)
```bash
scripts/06-backup-iphone.sh backups/working     # the copy we will modify
```

### 4. Convert and inject
```bash
scripts/07-run-pipeline.sh backups/working android/msgstore_shim.db \
    "ipa/app/Payload/WhatsApp.app/Frameworks/SharedModules.framework/WhatsAppChat.momd" \
    watoi-src/build/Release/watoi stickers
```
It prints before/after counts and an integrity check. ~40 seconds for half a million messages.

### 5. Restore
Turn **Find My iPhone off** (Settings → your name → Find My). The phone refuses the restore
otherwise, and it refuses *before* changing anything. If the toggle is greyed out, turn off
**Screen Time → Content & Privacy Restrictions** temporarily.
```bash
scripts/08-restore-iphone.sh backups/working
```
The iPhone shows a progress bar, reboots once, and WhatsApp opens with all your chats.
Turn Find My back on.

## Safety

* **Nothing is deleted on the Android.** Ever. It is only read.
* **The iPhone is not erased.** Restoring a backup taken minutes earlier changes only WhatsApp.
  Keep `backups/safety` until you are happy; `08-restore-iphone.sh backups/safety` puts the
  phone back exactly as it was.
* An **unencrypted** backup does not contain Keychain (passwords, Wi-Fi), Health, or call history.
  Those come back from **iCloud** after the restore if iCloud Keychain and Health sync are on.
  Check before you start.
* Your decrypted chat history ends up in plain SQLite on the Mac. Delete the working folder
  when done. Never commit it (the `.gitignore` here blocks every data file type).
* Unsupported by Meta/WhatsApp. It has worked for several people; it could break with a future
  schema change. The safety backup is your undo button.

## What does *not* transfer

| Item | Status |
|---|---|
| Photos, videos, voice notes, documents, GIFs | Placeholder text with the caption. The same mechanism as stickers could carry them; PRs welcome. |
| Stickers no longer on the Android | Placeholder. WhatsApp prunes old sticker files from the phone. |
| Sticker **favourites**, sticker packs | Not migrated (favourites live in Android's private `stickers.db`, unreachable without root). Re-add by long-pressing stickers in chats. |
| "X joined the group" system notices, missed-call entries, channel posts, broadcast-list copies | Not importable as chat rows. |
| Reactions, poll votes, view-once media | Skipped. Poll questions and events are kept as text. |
| Pinned / muted chat settings, wallpapers, profile, call history | Not migrated. |
| Contact names | Come from the iPhone's address book. |

## Troubleshooting

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md): `Find My` greyed out, adb disconnects,
OTP cooldowns, version mismatch, empty chat list after restore (and the iCloud round-trip fix),
`ipatool` auth failures.

## Credits

* [residentsummer/watoi](https://github.com/residentsummer/watoi) and the [kwvg fork](https://github.com/kwvg/watoi): the CoreData importer. GPL-3.0.
* [ElDavoo/wa-crypt-tools](https://github.com/ElDavoo/wa-crypt-tools): crypt15 decryption.
* [libimobiledevice](https://libimobiledevice.org): backup and restore without Finder.
* [n4ze3m's July 2026 write-up](https://n4ze3m.com/blog/recovering-whatsapp-chat-history-android-to-iphone-with-open-source-tools), which proved the route still works on current versions and pointed at the no-root crypt15 trick.

## License

GPL-3.0 (watoi is GPL-3.0 and the patch here is a derivative work). See [`LICENSE`](LICENSE).
