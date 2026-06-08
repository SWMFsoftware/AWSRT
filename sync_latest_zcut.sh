#!/bin/bash
set -euo pipefail

##########################################################
# This script copies over the the most recent z=0 cut
# to soslticedisk. Can be run with cron with any frequency
# Author: Gergely Koban
##########################################################

SRC_DIR="/nobackupp28/gkoban/SWMF_AWSRT/SWMF/run_realtime/IH/IO2"

REMOTE_USERHOST="gergelyk@solstice"
REMOTE_DIR="/data/CLEAR/nikolett/REALTIME"

REMOTE_ZCUT="${REMOTE_DIR}/zcut.out"
REMOTE_ORIG="${REMOTE_DIR}/zcut.out.original_filename.txt"

# Match only the intended .out files
shopt -s nullglob
candidates=( "${SRC_DIR}"/z=0_var_*_e*.out )
shopt -u nullglob

if (( ${#candidates[@]} == 0 )); then
  echo "No matching .out files found in: ${SRC_DIR}" >&2
  exit 1
fi

# Extract the timestamp part after "_e" and before ".out", then pick the max lexicographically.
# Example filename: z=0_var_1_e20260129-000400-000.out
latest_file="$(
  printf "%s\n" "${candidates[@]}" \
  | awk -F'/' '
      {
        fn=$NF
        if (match(fn, /_e([0-9]{8}-[0-9]{6}-[0-9]{3})\.out$/, m)) {
          print m[1] "\t" $0
        }
      }' \
  | sort -k1,1 \
  | tail -n 1 \
  | cut -f2-
)"

if [[ -z "${latest_file}" ]]; then
  echo "Found candidates, but none matched the expected _eYYYYMMDD-HHMMSS-mmm.out pattern." >&2
  exit 2
fi

base="$(basename "$latest_file")"

echo "Latest file selected: $latest_file"
echo "Copying to: ${REMOTE_USERHOST}:${REMOTE_ZCUT}"

# Ensure destination dir exists, then copy the file as zcut.out
ssh "${REMOTE_USERHOST}" "mkdir -p '${REMOTE_DIR}'"
scp -p "${latest_file}" "${REMOTE_USERHOST}:${REMOTE_ZCUT}"

# Set permissions on the remote copied file
ssh "${REMOTE_USERHOST}" "chmod 777 '${REMOTE_ZCUT}'"

# Write the original filename as a separate file on the remote side
ssh "${REMOTE_USERHOST}" "printf '%s\n' '${base}' > '${REMOTE_ORIG}'"

echo "Done."
echo "Remote original-filename marker: ${REMOTE_USERHOST}:${REMOTE_ORIG}"

