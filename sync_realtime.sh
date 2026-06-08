#!/bin/bash
set -euo pipefail

################################################
# Script for syncing the sat results to solstice
# Author: Gergely Koban
################################################

SRC="/nobackupp28/gkoban/SWMF_AWSRT/SWMF/run_realtime/sat_earth.sat"
DEST="gergelyk@solstice:/data/Simulations/gergelyk/Daily_SW/AWSRT/Realtime_BG_results/sat_earth.sat"

# Ensure destination directory exists
### ssh solstice "mkdir -p /data/Simulations/gergelyk/Daily_SW/AWSRT/Realtime_BG_results/"

# Sync
rsync -av --partial --inplace "$SRC" "$DEST"
