#!/bin/bash
# Restores the modified backup to the iPhone. The phone must be unlocked and Find My iPhone must be OFF
# (the device itself refuses with MBErrorDomain/211 otherwise; refusal happens before anything changes).
# usage: 08-restore-iphone.sh <backup_root>
set -euo pipefail
DIR="${1:?usage: $0 <backup_root>}"
idevicebackup2 restore --system --settings --reboot "$DIR"
