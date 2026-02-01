#!/bin/bash
#PBS -S /bin/bash
#PBS -N Realtime_test
#PBS -W group_list=s2994
#PBS -o /dev/null
#PBS -e /dev/null
# To run on the 28-core Electra Broadwell nodes (128GB/node or 4.5GB/core)
### PBS -l select=33:ncpus=28:model=bro_ele
#PBS -l select=50:ncpus=40:model=cas_ait
#PBS -q long
### PBS -q devel
#PBS -l walltime=10:00:00
####################################################


# Loading the modules
source /usr/share/Modules/init/bash
### module purge
module load comp-intel/2023.2.1
module load mpi-hpe/mpt.2.30
module load gcc/9.3
module use -a /swbuild/analytix/tools/modulefiles
module load miniconda3/v4

#Fix stack size issue
ulimit -s unlimited

exec >> /nobackupp28/gkoban/Realtime/SWMF/output_test.log 2>&1

SWMF_dir=/nobackupp28/gkoban/Realtime/SWMF
RUNDIR="{{RUNDIR}}"
SUBMISSION_DATA_DIR="{{CME_EVENT_DIR}}"

CME_IN="$SUBMISSION_DATA_DIR/CME.in"
CME_JSON="$SUBMISSION_DATA_DIR/processed_CME.json"

### set up the gap run
python3 $SWMF_dir/make_CMEin.py --infile $CME_IN --outdir $RUNDIR/SC
python3 $SWMF_dir/make_CMEtime.py \
  --cme-json $CME_JSON \
  --run-dir  $RUNDIR
python3 $SWMF_dir/make_amr_settings.py --run-dir $RUNDIR

cp $SWMF_dir/PARAM.in.gap $RUNDIR/SC/PARAM.tmp
cd $RUNDIR/SC
$SWMF_dir/share/Scripts/ParamConvert.pl PARAM.tmp ../PARAM.in
cd $RUNDIR

#run gaprun
mpiexec -n 2000 ./SWMF_solar.exe > runlog_`date +%y%m%d_%H%M`

rm -rf RESTART_n000000
./Restart.pl -v

#start CME run
cp $CME_IN "$RUNDIR/SC/CME.in"
cp $SWMF_dir/PARAM.in.CME $RUNDIR/SC/PARAM.tmp
cd $RUNDIR/SC
$SWMF_dir/share/Scripts/ParamConvert.pl PARAM.tmp ../PARAM.in

cd $RUNDIR
# Start PostProc.pl in the background
### ./PostProc.pl -n=16 -r=600 > PostProc.log 2>&1 &

# launch CME simulation
mpiexec -n 2000 ./SWMF_solar.exe > runlog_`date +%y%m%d_%H%M`


# ./PostProc.pl -M -cat RESULTS

exit 0
