#!/bin/bash
# Test version for recurrent cron job script
####
## SWMF directory
####
SWMF_DIR=/home4/mpetrenk/MODELS/SH/SWMF_solar/SWMF_MFLAMPA_DEV
####
## Collection of real-time infrastructure scripts
####
AWSRT=$SWMF_DIR/AWSRT
####
## Load IDL and init it for BASH
####
source /usr/share/Modules/init/bash
####
## By default, the IDL is not loaded 
module purge
module load idl
####
## Now, the IDL is present in the derictory below
####
IDL_DIR=/nasa/idl/toss4/8.9/idl89
####
## Add IDL to PATH
####
export PATH="$PATH:$IDL_DIR/bin:$IDL_DIR/lib:$IDL_DIR/lib/utilities"
####
## Set IDL_PATH
export IDL_PATH="$SWMF_DIR/share/IDL/General:<IDL_DEFAULT>"
export IDL_STARTUP="$SWMF_DIR/share/IDL/General/idlrc"
source ${IDL_DIR}/bin/idl_setup.bash
####
## Declare and cleanup real-time run directory
####
RUN_DIR=/nobackupp28/isokolov/run_realtime
rm -f $RUN_DIR/PostProc.log_* $RUN_DIR/PARAM.in_* $RUN_DIR/RESULTS/runlog_*
cd $RUN_DIR
idl $AWSRT/plot_2d_slice_movie.pro > log_2d_slice_movie
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
