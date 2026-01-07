#!/bin/tcsh
set AWSRT="/home4/mpetrenk/MODELS/SH/SWMF_solar/SWMF_MFLAMPA_DEV/AWSRT"
if ("$1" == "") then
    set RUN_DIR="/nobackupp28/isokolov/run_realtime"
else
    set RUN_DIR="$1"
endif
echo "RUN_DIR=$RUN_DIR"
source $AWSRT/sswidl.sh
$AWSRT/test_euv.sh $RUN_DIR
exit


