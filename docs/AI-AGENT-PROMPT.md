# Let an AI agent do it

This migration was originally performed by an AI coding agent (Claude Code, Oct 2026) running on a Mac,
with the phone's owner doing the taps the agent asked for. Any agent with shell access on a Mac can repeat it.
Paste the prompt below into Claude Code / Codex / Cursor / whatever you use, in a terminal on the Mac the
phones are plugged into.

---

```
I want to move my WhatsApp chat history from my Android phone to my iPhone WITHOUT factory-resetting
the iPhone and without losing any data on either phone. Both phones are connected to this Mac.

Use the open-source procedure in https://github.com/MdShahnawazSheikh/whatsapp-android-to-iphone-no-reset
Clone it, read README.md and docs/HOW-IT-WORKS.md, run scripts/00-check-tools.sh, then drive the numbered
scripts in scripts/ in order. Do every step you can from the Mac yourself; when a step needs my hands
(tapping on a phone, reading a code, entering a password) tell me exactly what to do and wait.

Rules:
- Take the safety backup of the iPhone (06-backup-iphone.sh) BEFORE anything else and never modify it.
- Never delete or modify anything on the Android. Read-only.
- After every script, report the printed counts to me and stop if any count is unexpected or an
  integrity check is not "ok".
- Before 08-restore-iphone.sh, show me the before/after counts and ask for my go-ahead.
- Keep my 64-digit key and decrypted database on this Mac only, and remind me to delete the work
  folder at the end.

Start by telling me the plan in 5 lines, then run 00-check-tools.sh.
```

---

## What the agent will ask you to do on the phones

1. **Android:** enable USB debugging (or Wireless debugging); in WhatsApp turn on *end-to-end encrypted
   backup* with the **64-digit key**, save the key, tap **Back up**, then send the key to the agent.
2. **Mac:** run `ipatool auth login --email <your Apple ID>` in a separate terminal (2FA code).
3. **iPhone:** make sure WhatsApp is updated to the App Store version; let the agent take the safety
   backup; then **register WhatsApp with your number** (skip iCloud restore / Android transfer); stop at
   the empty chat list.
4. **iPhone:** turn **Find My iPhone off** (greyed out? disable Screen Time content restrictions first).
   Turn it back on afterwards.
5. Keep the iPhone plugged in and unlocked during backup and restore.

## Tips for the agent operator

* OTP verification on the iPhone can hit WhatsApp's cooldown (hours). Pausing is safe at any point before
  the restore; nothing has changed on either phone.
* If the Android drops off USB during the pull, Wireless debugging over the same Wi-Fi is the fix.
* A full dry run is possible: run `07-run-pipeline.sh` on a *copy* of the safety backup and look at the
  counts before touching the real working backup.
