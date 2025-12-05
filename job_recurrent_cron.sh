#!/bin/bash
# Test version for recurrent cron job script
# Under developmen, more work is needed
STOPTIME=$(date -d "23 hours 20 minutes" +%s)
CURRENT_TIME=$(date +%s)
echo "$(($STOPTIME-$CURRENT_TIME))"
PBSTASKS=$(/PBS/bin/qstat -u $USER -W o=Jobname,s)
REGEX="SWMF_MFLAMPA_RT"
if [[ "$PBSTASKS" =~ $REGEX ]]; then
    echo "Model is still running"
fi
exit 0
