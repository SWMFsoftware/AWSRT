#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <run_directory> [check_interval_seconds] [stale_threshold_seconds] [max_restarts]"
    echo
    echo "Defaults:"
    echo "  check_interval_seconds = 600   (10 min)"
    echo "  stale_threshold_seconds = 1200 (20 min)"
    echo "  max_restarts = 3"
    exit 1
}

if [[ $# -lt 1 || $# -gt 4 ]]; then
    usage
fi

exec >> /nobackupp28/gkoban/SWMF_AWSRT/SWMF/watchdog.log 2>&1

RUNDIR="$1"
CHECK_INTERVAL="${2:-600}"
STALE_THRESHOLD="${3:-1200}"
MAX_RESTARTS="${4:-3}"

PBS_QDEL="/PBS/bin/qdel"
PBS_QSUB="/PBS/bin/qsub"

RESTART_JOBFILE="$RUNDIR/job_CME_restart.sh"
JOBID_FILE="$RUNDIR/jobid_history.txt"
SUCCESS_FILE="$RUNDIR/SWMF.SUCCESS"
LOGFILE="$RUNDIR/restart_watchdog.log"

if [[ ! -d "$RUNDIR" ]]; then
    echo "Error: run directory does not exist: $RUNDIR"
    exit 1
fi

if [[ ! -f "$RESTART_JOBFILE" ]]; then
    echo "Error: restart jobfile not found: $RESTART_JOBFILE"
    exit 1
fi

if [[ ! -f "$JOBID_FILE" ]]; then
    echo "Error: job ID file not found: $JOBID_FILE"
    exit 1
fi

if [[ ! -x "$PBS_QDEL" ]]; then
    echo "Error: qdel not found or not executable: $PBS_QDEL"
    exit 1
fi

if [[ ! -x "$PBS_QSUB" ]]; then
    echo "Error: qsub not found or not executable: $PBS_QSUB"
    exit 1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

get_current_jobid() {
    tail -n 1 "$JOBID_FILE" | tr -d '[:space:]'
}

get_restart_count() {
    local nlines
    nlines=$(grep -cve '^[[:space:]]*$' "$JOBID_FILE" || true)

    if (( nlines <= 1 )); then
        echo 0
    else
        echo $((nlines - 1))
    fi
}

find_latest_runlog() {
    find "$RUNDIR" -maxdepth 1 -type f -name 'runlog*' -printf '%T@ %p\n' \
        | sort -n \
        | tail -1 \
        | cut -d' ' -f2-
}

CURRENT_JOBID="$(get_current_jobid)"

if [[ -z "$CURRENT_JOBID" ]]; then
    echo "Error: could not read a valid job ID from $JOBID_FILE"
    exit 1
fi

RESTART_COUNT="$(get_restart_count)"

log "Starting watchdog"
log "Run directory      : $RUNDIR"
log "Current job ID     : $CURRENT_JOBID"
log "Job ID file        : $JOBID_FILE"
log "Check interval     : $CHECK_INTERVAL s"
log "Stale threshold    : $STALE_THRESHOLD s"
log "Max restarts       : $MAX_RESTARTS"
log "Current restarts   : $RESTART_COUNT"
log "Restart jobfile    : $RESTART_JOBFILE"

if [[ -f "$SUCCESS_FILE" ]]; then
    log "Found $SUCCESS_FILE . Simulation finished successfully. Exiting."
    exit 0
fi

if (( RESTART_COUNT >= MAX_RESTARTS )); then
    log "Maximum number of restarts reached ($RESTART_COUNT >= $MAX_RESTARTS). Exiting."
    exit 0
fi

while true; do
    if [[ -f "$SUCCESS_FILE" ]]; then
        log "Found $SUCCESS_FILE . Simulation finished successfully. Exiting."
        exit 0
    fi

    RESTART_COUNT="$(get_restart_count)"
    if (( RESTART_COUNT >= MAX_RESTARTS )); then
        log "Maximum number of restarts reached ($RESTART_COUNT >= $MAX_RESTARTS). Exiting."
        exit 0
    fi

    CURRENT_JOBID="$(get_current_jobid)"
    if [[ -z "$CURRENT_JOBID" ]]; then
        log "Error: could not read current job ID from $JOBID_FILE"
        exit 1
    fi

    latest_runlog="$(find_latest_runlog || true)"

    if [[ -z "${latest_runlog:-}" ]]; then
        log "No runlog* file found in $RUNDIR"
    else
        now=$(date +%s)
        mtime=$(stat -c %Y "$latest_runlog")
        age=$((now - mtime))

        log "Latest runlog: $latest_runlog"
        log "Runlog age: ${age} s"

        if (( age >= STALE_THRESHOLD )); then
            log "Runlog is stale for at least $STALE_THRESHOLD s. Restarting job."
            log "Killing job $CURRENT_JOBID"

            if "$PBS_QDEL" "$CURRENT_JOBID"; then
                log "qdel succeeded for $CURRENT_JOBID"
            else
                log "Warning: qdel failed for $CURRENT_JOBID"
            fi

            log "Submitting restart job: $RESTART_JOBFILE"
            new_jobid="$("$PBS_QSUB" "$RESTART_JOBFILE")"
            new_jobid="${new_jobid%%.*}"
            new_jobid="$(echo "$new_jobid" | tr -d '[:space:]')"

            if [[ -z "$new_jobid" ]]; then
                log "Error: qsub did not return a new job ID"
                exit 1
            fi

            printf "%s\n" "$new_jobid" >> "$JOBID_FILE"
            log "Restart job submitted with new job ID: $new_jobid"
            log "Appended new job ID to $JOBID_FILE"

            exit 0
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
