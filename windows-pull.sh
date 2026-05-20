#!/bin/bash
# windows-pull.sh
# Part of Project EST — Eastslide Microsoft Exit
# Pulls selected data from Windows NVME (nvme1n1p3) to ~/fossome/windows-local
#
# Prerequisites:
#   - Windows NVME mounted read-only at /mnt/windows
#   - ~/fossome/windows-local exists
#
# Mount command (if not already mounted):
#   sudo mount -o ro /dev/nvme1n1p3 /mnt/windows
#
# Run inside tmux:
#   tmux new-session -s windows-pull
#   bash ~/ProjectEST/windows-pull.sh

LOG=~/fossome/windows-pull.log
DEST=~/fossome/windows-local

echo "=== Windows pull started: $(date) ===" | tee -a "$LOG"

SOURCES=(
    "/mnt/windows/Users/Tom|$DEST/Users-Tom"
    "/mnt/windows/home/Tino|$DEST/home-Tino"
    "/mnt/windows/!Archives|$DEST/Archives"
    "/mnt/windows/!Scripts|$DEST/Scripts"
    "/mnt/windows/!Logs|$DEST/Logs"
)

for entry in "${SOURCES[@]}"; do
    SRC="${entry%%|*}"
    DST="${entry##*|}"

    echo "" | tee -a "$LOG"
    echo "--- Pulling: $SRC -> $DST ---" | tee -a "$LOG"
    echo "Started: $(date)" | tee -a "$LOG"

    mkdir -p "$DST"

    rsync -av \
        --progress \
        --exclude="AppData/" \
        --exclude="*.tmp" \
        --exclude="*.temp" \
        --exclude="Thumbs.db" \
        --exclude="desktop.ini" \
        --log-file="$LOG" \
        "$SRC/" "$DST/"

    echo "Finished: $(date)" | tee -a "$LOG"
done

echo "" | tee -a "$LOG"
echo "=== Windows pull completed: $(date) ===" | tee -a "$LOG"
