#!/bin/bash
############## Mimics the BASH environment for Xianyu's IDL tool
############## to visualize EUV+X images
############## Such environment is used in continuous real-time simulation (RT)
#
############## As all RT simulations, this script is called from SWMF dir
SWMF_dir=`pwd`
echo "SWMF dir: $SWMF_dir"
############## before running test_euv.sh one needs to run
############## make test8
############## Once done, in the directory below there is a synthetic
############## EUV plot
RUNDIR=$SWMF_dir/run_test/RESULTS/SC
############## Loading the modules: use the full path to IDL
############## If modified, file AWSRT/sswidl.sh should be modified too
IDL_DIR=/Applications/NV5/idl91
export IDL_DIR
source ${IDL_DIR}/bin/idl_setup.bash
############## Folder with RT scripts and parameter files, git repository,
############## can be downloaded from the SWMF directory with
############## share/Scripts/gitclone AWSRT
############## The current script needs to be copied to the SWMF directory:
############## cp AWSRT/test_euv.sh .
AWSRT=$SWMF_dir/AWSRT
export IDL_PATH="${IDL_DIR}/lib:$AWSRT:$SWMF_dir/share/IDL/General:<IDL_DEFAULT>"
echo "IDL_PATH=$IDL_PATH"
############## Use the full path to SSW
############## if modified, file AWSRT/sswidl.sh should be modified too 
SSW=${HOME}/ssw
export SSW
############## Initialize ssw/idl interface
$AWSRT/sswidl.sh
############## for "all" aia synthetic images
for namefile in ${RUNDIR}/los_sdo_aia*.out
do
    echo ".r swmf_read_xuv">idlrun
    echo "swmf_read_xuv,'${namefile}' ">>idlrun
    echo "exit">>idlrun
    $SSW/gen/setup/ssw_idl "idlrun"
done
exit 0
