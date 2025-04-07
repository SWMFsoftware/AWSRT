#!/bin/bash
SWMF_dir=`pwd`
echo "SWMF dir: $SWMF_dir"
RUNDIR=$SWMF_dir/run_test/RESULTS/SC
# Loading the modules: use the full path to IDL here
IDL_DIR=/Applications/NV5/idl91
export IDL_DIR
source ${IDL_DIR}/bin/idl_setup.bash
#export IDL_PATH="${IDL_DIR}/lib:$SWMF_dir/AWSRT:${HOME}/SWMF_NO_HISTORY/share/IDL/General:<IDL_DEFAULT>"
#export PATH=${PATH}:$HOME/.local/bin
# Loading the modules: use the full path to SSW here
SSW=${HOME}/ssw
export SSW
#export SSW_INSTR="gen soho aia hmi xrt eit lasco secchi nrl festival sunspice"
#export SSWDB=${HOME}/ssw
#export SSW_SITE_SETUP=$SSW/site/setup
$HOME/.local/bin/sswidl.sh
#$export IDL_STARTUP=$HOME/.startup_idl.pro
for namefile in ${RUNDIR}/los_sdo_aia*.out
do
    echo ".r swmf_read_xuv">idlrun
    echo "swmf_read_xuv,'${namefile}' ">>idlrun
    $SSW/gen/setup/ssw_idl "idlrun"
done
exit 0
