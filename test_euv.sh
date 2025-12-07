#!/bin/bash
##############
############## Runs Xianyu's script to visualize EUV+X images
##############
SWMF_dir=/home4/mpetrenk/MODELS/SH/SWMF_solar/SWMF_MFLAMPA_DEV
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
####
## Declare and cleanup real-time run directory
####
RUN_DIR=/nobackupp28/isokolov/run_realtime

DATA_DIR=$RUN_DIR/RESULTS/SC

############## Use the full path to SSW
############## if modified, file AWSRT/sswidl.sh should be modified too 
SSW=${HOME}/ssw
export SSW
############## Initialize ssw/idl interface
$AWSRT/sswidl.sh
############## for "all" aia synthetic images
for namefile in $DATA_DIR/los_sdo_aia*.out
do
    python3 $AWSRT/get_euv_obs.py ${namefile}
    echo ".r $AWSRT/swmf_read_xuv">idlrun
    echo "swmf_read_xuv,'${namefile}',if_compare=1,data_dir='$RUN_DIR/TEMP' ">>idlrun
    echo "exit">>idlrun
    $SSW/gen/setup/ssw_idl "idlrun"
done
exit 0
