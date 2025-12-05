#!/bin/bash
# Test version for recurrent cron job script
SWMF_DIR=/home4/mpetrenk/MODELS/SH/SWMF_solar/SWMF_MFLAMPA_DEV
AWSRT=$SWMF_DIR/AWSRT
module purge
module load idl
IDL_DIR=/nasa/idl/toss4/8.9/idl89
echo "PATH: $PATH"
export PATH="$PATH:$IDL_DIR/bin:$IDL_DIR/lib:$IDL_DIR/lib/utilities"
echo "New PATH: $PATH"
exit 0
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
