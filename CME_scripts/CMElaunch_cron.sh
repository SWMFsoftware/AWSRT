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
SOURCE_DIR=/nobackupp28/gkoban/SWMF_AWSRT/SWMF/run_realtime
SWMF_dir=/nobackupp28/gkoban/SWMF_AWSRT/SWMF

wait_for_job_running() {
  local jobID="$1"
  local log="$2"
  local poll="${3:-10}"          # seconds
  local timeout="${4:-7200}"     # seconds (2 hours)
  local pattern="${jobID%%.*}"

  local start_ts now_ts elapsed out line state

  start_ts=$(date +%s)

  while true; do
    now_ts=$(date +%s)
    elapsed=$(( now_ts - start_ts ))
    if (( elapsed > timeout )); then
      echo "$(date -Is) TIMEOUT waiting for job $jobID to start running" >>"$log"
      return 1
    fi

    out="$(/PBS/bin/qstat "$jobID" -W o=SeqNo,Jobname,s,Elapwallt 2>&1 || true)"

    # Terminal conditions: finished or not found
    if grep -q "has finished" <<<"$out" || grep -qiE "Unknown Job Id|unknown job|Job has finished|not found" <<<"$out"; then
      echo "$(date -Is) Job $jobID ended/vanished before reaching R. qstat output: $out" >>"$log"
      return 2
    fi

    line="$(printf '%s\n' "$out" | grep -F "$pattern" | head -n 1 || true)"
    if [[ -n "$line" ]]; then
      state="$(awk '{print $3}' <<<"$line")"
      echo "$(date -Is) job=$jobID state=$state line=$line" >>"$log"

      if [[ "$state" == "R" ]]; then
        echo "$(date -Is) Job $jobID is RUNNING" >>"$log"
        return 0
      fi
    else
      echo "$(date -Is) job=$jobID no job line yet (qstat returned something unexpected)" >>"$log"
    fi

    sleep "$poll"
  done
}

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
  chmod 777 "$d/LAUNCHED"

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
  #/PBS/bin/qsub job_CME.sh

  jobID=$(/PBS/bin/qsub job_CME.sh)
  jobID=${jobID%%.*}

  ### sleep 600
  ### /nobackupp28/gkoban/SWMF_AWSRT/SWMF/sync_spio2.sh "$SWMF_dir/$RUNDIR"

  LOG="/nobackupp28/gkoban/SWMF_AWSRT/SWMF/sync_spio2_test.log"
  mkdir -p "$(dirname "$LOG")"
  
  if wait_for_job_running "$jobID" "$LOG" 60 14400; then

   marker="$SWMF_dir/$RUNDIR/CME_runstarted"
   marker_timeout=2400   # seconds
   marker_poll=60        # seconds

   t0=$(date +%s)
   while [[ ! -e "$marker" ]]; do
     now=$(date +%s)
     if (( now - t0 >= marker_timeout )); then
       echo "$(date -Is) Not syncing; marker $marker not found after ${marker_timeout}s" >>"$LOG" 2>&1
       exit 0
     fi
     sleep "$marker_poll"
   done

   echo "$(date -Is) starting sync for $SWMF_dir/$RUNDIR" >>"$LOG" 2>&1
   /nobackupp28/gkoban/SWMF_AWSRT/SWMF/sync_spio2.sh "$SWMF_dir/$RUNDIR" >>"$LOG" 2>&1
   /PBS/bin/qsub "$SWMF_dir/$RUNDIR/job_realtime_mittens.pfe" >>"$LOG" 2>&1

  else
    rc=$?
    echo "$(date -Is) Not syncing; job $jobID never reached RUNNING (rc=$rc)" >>"$LOG" 2>&1
  fi

  exit 0
  done

echo "$(date -Is) no new CME was found"
exit 0

