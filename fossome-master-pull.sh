#!/bin/bash
# fossome-master-pull.sh
# Part of Project EST — Eastslide Microsoft Exit
# Chains windows-pull.sh and xternal-pull.sh sequentially
# Run this AFTER the OneDrive rclone pull has completed
#
# Run inside tmux:
#   tmux new-session -s master-pull
#   bash ~/ProjectEST/fossome-master-pull.sh

LOG=~/fossome/master-pull.log
SCRIPTS=~/ProjectEST

echo "======================================" | tee -a "$LOG"
echo "=== Fossome master pull started: $(date) ===" | tee -a "$LOG"
echo "======================================" | tee -a "$LOG"

# --- Preflight checks ---

echo "" | tee -a "$LOG"
echo "--- Preflight checks ---" | tee -a "$LOG"

# Check Windows NVME is mounted
if [ ! -d "/var/mnt/windows/Users/Tom" ]; then
    echo "ERROR: Windows NVME not mounted at /var/mnt/windows" | tee -a "$LOG"
    echo "Mount it with: sudo mount -o ro /dev/nvme1n1p3 /var/mnt/windows" | tee -a "$LOG"
    exit 1
fi
echo "OK: Windows NVME mounted" | tee -a "$LOG"

# Check XTERNAL drive is mounted
if [ ! -d "/run/media/tino/XTERNAL/Photos" ]; then
    echo "ERROR: XTERNAL drive not found at /run/media/tino/XTERNAL" | tee -a "$LOG"
    echo "Plug in the XTERNAL drive and ensure it is mounted, then re-run." | tee -a "$LOG"
    exit 1
fi
echo "OK: XTERNAL drive mounted" | tee -a "$LOG"

# Check fossome destination exists
if [ ! -d ~/fossome ]; then
    echo "ERROR: ~/fossome directory not found" | tee -a "$LOG"
    exit 1
fi
echo "OK: ~/fossome destination exists" | tee -a "$LOG"

# Check disk space — warn if less than 400GB free
AVAIL=$(df --output=avail -BG ~/fossome | tail -1 | tr -d 'G')
echo "Available space on destination: ${AVAIL}GB" | tee -a "$LOG"
if [ "$AVAIL" -lt 400 ]; then
    echo "WARNING: Less than 400GB free — monitor space during pull" | tee -a "$LOG"
fi

echo "" | tee -a "$LOG"
echo "Preflight passed. Starting pulls." | tee -a "$LOG"

# --- Phase 1: Windows local pull ---

echo "" | tee -a "$LOG"
echo "======================================" | tee -a "$LOG"
echo "=== Phase 1: Windows local pull ===" | tee -a "$LOG"
echo "======================================" | tee -a "$LOG"

bash "$SCRIPTS/windows-pull.sh"

if [ $? -ne 0 ]; then
    echo "ERROR: windows-pull.sh failed — aborting master pull" | tee -a "$LOG"
    exit 1
fi

echo "=== Phase 1 complete: $(date) ===" | tee -a "$LOG"

# --- Phase 2: XTERNAL pull ---

echo "" | tee -a "$LOG"
echo "======================================" | tee -a "$LOG"
echo "=== Phase 2: XTERNAL pull ===" | tee -a "$LOG"
echo "======================================" | tee -a "$LOG"

bash "$SCRIPTS/xternal-pull.sh"

if [ $? -ne 0 ]; then
    echo "ERROR: xternal-pull.sh failed" | tee -a "$LOG"
    exit 1
fi

echo "=== Phase 2 complete: $(date) ===" | tee -a "$LOG"

# --- Done ---

echo "" | tee -a "$LOG"
echo "======================================" | tee -a "$LOG"
echo "=== All pulls complete: $(date) ===" | tee -a "$LOG"
echo "======================================" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "Next step: run rmlint across ~/fossome to dedupe" | tee -a "$LOG"
echo "  rmlint ~/fossome --output-directory ~/fossome/rmlint-report" | tee -a "$LOG"
