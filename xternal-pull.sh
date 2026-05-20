#!/bin/bash
# xternal-pull.sh
# Part of Project EST — Eastslide Microsoft Exit
# Pulls selected data from XTERNAL USB drive to ~/fossome/xternal
#
# Prerequisites:
#   - XTERNAL drive mounted (automounts to /run/media/tino/XTERNAL)
#   - ~/fossome/xternal exists
#
# Run inside tmux:
#   tmux new-session -s xternal-pull
#   bash ~/ProjectEST/xternal-pull.sh
#
# Note: Photos/ and Photos_Org/ are complementary — the AI script moved
# files from Photos/ into Photos_Org/ by type, with dupes going to
# _Quarantine. Pull both; rmlint will dedupe across fossome later.

LOG=~/fossome/xternal-pull.log
SRC=/run/media/tino/XTERNAL
DEST=~/fossome/xternal

echo "=== XTERNAL pull started: $(date) ===" | tee -a "$LOG"

# Verify drive is mounted
if [ ! -d "$SRC/Photos" ]; then
    echo "ERROR: XTERNAL drive not found at $SRC" | tee -a "$LOG"
    echo "Plug in the drive and ensure it is mounted, then re-run." | tee -a "$LOG"
    exit 1
fi

SOURCES=(
    "$SRC/Photos|$DEST/Photos"
    "$SRC/Photos_Org|$DEST/Photos_Org"
    "$SRC/BackupFromLeRock|$DEST/BackupFromLeRock"
)

for entry in "${SOURCES[@]}"; do
    SOURCE="${entry%%|*}"
    DESTINATION="${entry##*|}"

    echo "" | tee -a "$LOG"
    echo "--- Pulling: $SOURCE -> $DESTINATION ---" | tee -a "$LOG"
    echo "Started: $(date)" | tee -a "$LOG"

    mkdir -p "$DESTINATION"

    rsync -av \
        --progress \
        --exclude="*.tmp" \
        --exclude="*.temp" \
        --exclude="Thumbs.db" \
        --exclude="desktop.ini" \
        --log-file="$LOG" \
        "$SOURCE/" "$DESTINATION/"

    echo "Finished: $(date)" | tee -a "$LOG"
done

echo "" | tee -a "$LOG"
echo "=== XTERNAL pull completed: $(date) ===" | tee -a "$LOG"
