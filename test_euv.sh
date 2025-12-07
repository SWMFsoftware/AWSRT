#!/bin/bash
##############
############## Runs Xianyu's script to visualize EUV+X images
##############
##
####
## Set run directory in which to process the data
if(! $?rundir ) then
  RUN_DIR=/nobackupp28/isokolov/run_realtime
else
  RUN_DIR=$rundir
endif
####
## Collection of real-time infrastructure scripts
####
############# VERSION FOR PLEIADES ##############################
AWSRT=/home4/mpetrenk/MODELS/SH/SWMF_solar/SWMF_MFLAMPA_DEV/AWSRT
####
## Load IDL and init it for BASH, Pleiades version
####
source /usr/share/Modules/init/bash
####
## By default, the IDL is not loaded
module purge
module load idl
module use -a /swbuild/analytix/tools/modulefiles
module load miniconda3/v4
module load cuda/11.0
module use -a /nasa/modulefiles/testing
module load python3/3.8.8
####
## Now, the IDL is present in the derictory below
####
IDL_DIR=/nasa/idl/toss4/8.9/idl89
source ${IDL_DIR}/bin/idl_setup.bash
############## Use the full path to SSW
############## if modified, file AWSRT/sswidl.sh should be modified too 
SSW=/home6/ataktaki/ssw
export SSW
############ END OF VERSION FOR PLEIADES
############## Initialize ssw/idl interface
$AWSRT/sswidl.sh
#
DATA_DIR=RESULTS/SC
############## for "all" aia synthetic images
cd $RUN_DIR
for namefile in $DATA_DIR/los_sdo_aia*.out
do
    python3 $AWSRT/get_euv_obs.py ${namefile}
    echo ".r $AWSRT/swmf_read_xuv">idlrun
    echo "swmf_read_xuv,'${namefile}',if_compare=1,data_dir='TMP' ">>idlrun
    echo "exit">>idlrun
    $SSW/gen/setup/ssw_idl "idlrun"
done
exit 0
