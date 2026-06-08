#!/bin/bash

##################################################
# The purpose of this script is to check whether
# the background job is submitted, and if not,
# submit it. It can be ran from cron with the
# preferred frequency, eg 1 hour, 30 minutes, etc.
# Author: Gergely Koban
##################################################

source /usr/share/Modules/init/bash

# Standard aliases
alias rm='/bin/rm -i'
alias mv='/bin/mv -i'
alias cp='/bin/cp -i'



JOBNAME="SWMF_MFLAMPA_RT"
JOBSCRIPT="/nobackupp28/gkoban/SWMF_AWSRT/SWMF/job_recurrent_cron_failsafe.sh"
LOGFILE="/nobackupp28/gkoban/SWMF_AWSRT/SWMF/recurrent_cron.log"

mkdir -p "$(dirname "$LOGFILE")"

# Check if job already exists (queued or running)
if /PBS/bin/qstat -u "$USER" -W o=Jobname,s | awk '{print $1}' | grep -qx "$JOBNAME"; then
    echo "$(date -Is) $JOBNAME already exists (queued or running). Not submitting." >> "$LOGFILE"
else
    echo "$(date -Is) $JOBNAME not found. Submitting job." >> "$LOGFILE"

    cd /nobackupp28/gkoban/SWMF_AWSRT/SWMF || exit 1

    jobID=$(/PBS/bin/qsub "$JOBSCRIPT")
    jobID=${jobID%%.*}

    echo "$(date -Is) Submitted job with ID $jobID" >> "$LOGFILE"
fi
