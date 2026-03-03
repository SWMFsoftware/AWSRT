#!/usr/bin/env bash
set -euo pipefail

# ---- CONFIG ----
SRC_BASE="${1:-}"
SRC_DIR="${SRC_BASE}/SP/IO2"
DEST="gergelyk@solstice:/data/CLEAR/nikolett/REALTIME"
INTERVAL=600   # 10 minutes
MAX_IDLE=2

# ---- SANITY CHECKS ----
if [[ -z "${SRC_BASE}" ]]; then
  echo "Usage: $0 <base_directory>" >&2
  exit 1
fi

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "Error: ${SRC_DIR} does not exist" >&2
  exit 1
fi

# ---- STATE ----
idle_count=0

# csh ${SRC_BASE:t} == bash basename
base_name="$(basename "${SRC_BASE}")"

echo "Starting rsync monitor on ${SRC_DIR}"
echo "Will abort after ${MAX_IDLE} idle cycles"

# --- FOLDER CREATION (optional; kept commented like your original) ---
# mkdir -p "${SRC_BASE}/${base_name}"
# rsync -a --delete "${SRC_BASE}/${base_name}/" "${DEST}/"
/usr/bin/rsync -az --partial --perms --chmod=ugo=rwx "${SRC_BASE}/PARAM.in" "${DEST}/${base_name}/"

# ---- LOOP ----
while true; do
  echo "[$(date)] Running rsync..."

  # Count how many file names rsync reports via --out-format
  rsync_count="$(
    /usr/bin/rsync -az --partial --perms --chmod=ugo=rwx --out-format="%n" \
      "${SRC_DIR}/" "${DEST}/${base_name}/" | wc -l
  )"

  if [[ "${rsync_count}" -eq 0 ]]; then
    ((idle_count++))
    echo "No changes detected (idle ${idle_count}/${MAX_IDLE})"
  else
    idle_count=0
    echo "Changes detected, counter reset"
  fi

  if [[ "${idle_count}" -ge "${MAX_IDLE}" ]]; then
    echo "No changes for ${MAX_IDLE} cycles — aborting."
    exit 0
  fi

  sleep "${INTERVAL}"
done

