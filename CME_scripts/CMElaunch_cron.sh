#!/usr/bin/env bash
set -euo pipefail

source /usr/share/Modules/init/bash

# Standard aliases
alias rm='/bin/rm -i'
alias mv='/bin/mv -i'
alias cp='/bin/cp -i'

module use -a /swbuild/analytix/tools/modulefiles
module load miniconda3/v4


CME_ROOT="/nobackupp28/nbiro/CME_pipeline"
MANIFEST_DIR="/home6/gkoban/Realtime"
MANIFEST_FILE="$MANIFEST_DIR/cme_launched_manifest.tsv"
### LOCKFILE="$MANIFEST_DIR/.cme_dispatch.lock"
SOURCE_DIR=/nobackupp28/gkoban/Realtime/SWMF/run_realtime
SWMF_dir=/nobackupp28/gkoban/Realtime/SWMF

mkdir -p "$MANIFEST_DIR"

### Prevent overlapping cron invocations
### exec 200>"$LOCKFILE"
### flock -n 200 || exit 0

shopt -s nullglob

# Candidate CME event dirs matching: YYYY-MM-DD_HH-MM-SS
event_dirs=( "$CME_ROOT"/20??-??-??_??-??-?? )

# Sort chronologically (lexicographic works for this format)
IFS=$'\n' event_dirs=( $(printf "%s\n" "${event_dirs[@]}" | sort) )
unset IFS

for d in "${event_dirs[@]}"; do
  # (a) required files exist
  [[ -f "$d/CME.in" ]] || continue
  [[ -f "$d/processed_CME.json" ]] || continue

  # (b) not already launched
  [[ ! -f "$d/LAUNCHED" ]] || continue

  base="$(basename "$d")"                 # 2026-01-18_18-09-00
  ymd="${base:0:4}${base:5:2}${base:8:2}" # 20260118
  hm="${base:11:2}${base:14:2}"           # 1809
  RUNDIR="run_CME_${ymd}_${hm}"

  now="$(date -Is)"

  # Create marker FIRST so cron can't re-launch this event
  # Put some useful info in it for debugging/audit.
  {
    echo "timestamp=$now"
    echo "event_dir=$d"
    echo "event_name=$base"
    echo "rundir=$RUNDIR"
    echo "host=$(hostname)"
    echo "pid=$$"
  } > "$d/LAUNCHED"

  # Append to manifest (audit trail)
  # Columns: iso_time, event_dirname, rundir, full_event_path
  printf "%s\t%s\t%s\t%s\n" "$now" "$base" "$RUNDIR" "$d" >> "$MANIFEST_FILE"

  echo "RUNDIR=$RUNDIR"

  CYCLE_DIR=$(
  python3 $SWMF_dir/pick_cycle.py \
    --run-realtime "$SOURCE_DIR" \
    --cme-root "$d"
  )
  echo "Picked cycle: $CYCLE_DIR"

  "$SWMF_dir/setup_CMEdir.sh" \
   --cycle "$CYCLE_DIR" \
   --rundir "$SWMF_dir/$RUNDIR"

  python3 $SWMF_dir/make_jobscript.py \
  --swmf-dir $SWMF_dir \
  --template "launch_cme.sh" \
  --run-dir $SWMF_dir/$RUNDIR \
  --cme-event-dir "$d" 

  cd $SWMF_dir/$RUNDIR
  ### /PBS/bin/qsub job_realtime_mittens.pfe
  /PBS/bin/qsub job_CME.sh

  exit 0
done

echo "$(date -Is) no new CME was found"
exit 0

