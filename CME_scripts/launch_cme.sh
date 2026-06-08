#!/bin/bash
#PBS -S /bin/bash
#PBS -N Realtime_CME
#PBS -W group_list=s2994
### PBS -o /dev/null
### PBS -e /dev/null
#PBS -m be
# To run on the 28-core Electra Broadwell nodes (128GB/node or 4.5GB/core)
### PBS -l select=72:ncpus=28:model=bro_ele
#PBS -l select=50:ncpus=40:model=cas_ait
#PBS -q long
### PBS -q R24216227
### PBS -q devel
#PBS -l walltime=10:00:00
####################################################

#####################################################
# Jobscript for the CME runs for AWSRT. Automatically
# compiles the .in files and creates the parameter
# file. Launches the gaprun, then the CME run and 
# MITTENS.
# Author: Gergely Koban 
####################################################

# Loading the modules
source /usr/share/Modules/init/bash
### module purge
module load comp-intel/2023.2.1
module load mpi-hpe/mpt.2.30
module load gcc/9.3
module use -a /swbuild/analytix/tools/modulefiles
module load miniconda3/v4

# Fix stack size issue
ulimit -s unlimited

exec >> /nobackupp28/gkoban/SWMF_AWSRT/SWMF/output_CME.log 2>&1

SWMF_dir=/nobackupp28/gkoban/SWMF_AWSRT/SWMF
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
python3 $SWMF_dir/make_stoptime.py $RUNDIR

cp $SWMF_dir/PARAM.in.gap $RUNDIR/SC/PARAM.tmp
cd $RUNDIR/SC
$SWMF_dir/share/Scripts/ParamConvert.pl PARAM.tmp ../PARAM.in
cd $RUNDIR

# run gaprun
NPROCS=$(wc -l < "$PBS_NODEFILE")
mpiexec -n $((NPROCS - 10)) ./SWMF_solar.exe > runlog_$(date +%y%m%d_%H%M)

mv RESTART_n000000/ RESTART_beforegaprun/
./Restart.pl -v

#start CME run
python3 $SWMF_dir/make_injection.py $CME_JSON $RUNDIR
cp $CME_IN "$RUNDIR/SC/CME.in"
cp $RUNDIR/SP/IO2/LONLAT.earth $RUNDIR/SC
rm -f $RUNDIR/SP/IO2/satflux_earth.out
rm -f $RUNDIR/IH/IO2/sat_earth_*
cp $SWMF_dir/PARAM.in.CME $RUNDIR/SC/PARAM.tmp
cd $RUNDIR/SC
$SWMF_dir/share/Scripts/ParamConvert.pl PARAM.tmp ../PARAM.in

cd $RUNDIR

touch $RUNDIR/CME_runstarted

# Start PostProc.pl in the background
./PostProc.pl -r=180 -n=10 > PostProc.log 2>&1 &

### $SWMF_dir/sync_spio2.sh "$RUNDIR" \
###     > "$RUNDIR/sync_spio2.log" 2>&1 &
### SYNC_PID=$!

# launch CME simulation
mpiexec -n $((NPROCS - 10)) ./SWMF_solar.exe > runlog_$(date +%y%m%d_%H%M)


# ./PostProc.pl -M -cat RESULTS

exit 0
