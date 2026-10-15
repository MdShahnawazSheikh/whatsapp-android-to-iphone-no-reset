# Troubleshooting

**`Find My iPhone` toggle is greyed out**
Settings → Screen Time → Content & Privacy Restrictions → switch the main toggle off temporarily (or set
*Location Services* and *Account Changes* to "Allow"). Also clear any "Finish setting up / Update Apple ID
settings" banner at the top of Settings. Then Settings → your name → Find My → Find My iPhone → off.
Re-enable both when done.

**`Restore Failed (Error Code 211)` / `Find My iPhone must be disabled`**
Exactly that. The device refused before changing anything; turn Find My off and rerun.

**`adb pull` stalls at a few hundred KB, or the device vanishes mid-transfer**
Seen on OPPO/ColorOS through a USB hub. Turn on Developer options → *Wireless debugging* on the same Wi-Fi.
`adb mdns services` lists it and `adb devices` shows it automatically if USB debugging was already authorised.
Set *Stay awake* in Developer options too.

**`adb: more than one device/emulator`**
USB and Wi-Fi both connected. The scripts pick the Wi-Fi one; or `adb -s <serial> …`.

**No `msgstore.db.crypt15` on the phone, only `crypt14`**
E2E encrypted backup is not enabled or no backup was made after enabling it. WhatsApp → Settings → Chats →
Chat backup → End-to-end encrypted backup → Turn on → *Use 64-digit encryption key instead* → then tap Back up.

**`wadecrypt` fails**
Key must be the 64 hex digits with no spaces. `wainfo msgstore.db.crypt15` tells you what kind of file it is.

**WhatsApp OTP cooldown ("try again in 5 hours")**
WhatsApp rate-limits verification attempts. Don't retry; wait for the call option. Pausing is safe.

**`ipatool` authentication errors**
Run `ipatool auth login --email …` in an interactive terminal (needs the 2FA prompt). If the Homebrew
`ipatool` keeps failing, try `ipatool-rs`. The model file is the only thing needed from the `.ipa`.

**`.ipa` version ≠ iPhone WhatsApp version**
Update WhatsApp on the iPhone (App Store → profile → Updates) until `04-get-ipa.sh` prints matching versions.
The CoreData model must match the store.

**`xcodebuild` error: deployment target 10.11 unsupported**
Already handled by `05-build-watoi.sh` (`MACOSX_DEPLOYMENT_TARGET=12.0`). Needs full Xcode, not just CLI tools.

**watoi: `no such column: raw_string_jid` / `no such table: messages`**
You ran it on the raw `msgstore.db`. Run it on `msgstore_shim.db` from `03-build-shim.sh`.

**watoi: `NSInvalidArgumentException … nil key`**
Fixed by `watoi/watoi.patch` (null JID guards). Make sure `05-build-watoi.sh` applied it.

**`backup incomplete or WhatsApp not in it`**
WhatsApp must be installed *and registered* on the iPhone before the working backup, or `ChatStorage.sqlite`
isn't there. Backup encryption must be off (`06-backup-iphone.sh` checks).

**Chats show up empty / chat list empty after restore**
Shouldn't happen with `post.sh` (it sets the last-message pointers). If it does: in WhatsApp on the iPhone
make an iCloud backup, delete and reinstall WhatsApp, register, choose *Restore Chat History*. The data is in
the database; this just makes WhatsApp re-index it.

**Stickers show as `<sticker>` text**
That sticker's file was no longer on the Android (WhatsApp prunes them), or `03-build-shim.sh` was run without
the stickers directory. `03-build-shim.sh` prints how many sticker messages have a file available.

**Group messages show phone numbers instead of names**
Sender names come from the iPhone address book. Hidden-number (LID) senders that `jid_map` could not resolve
keep their LID; the shim prints that count (it was 0 in the reference run).

**I want to undo everything**
`scripts/08-restore-iphone.sh backups/safety` restores the pre-registration state of the iPhone. The Android
was never modified.
