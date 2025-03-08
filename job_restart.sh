#!/bin/bash      
#SBATCH -n 324                                  # Number of tasks
#SBATCH -o AWSOMR_rt.o%j                        # Output
#SBATCH -e AWSOMR_rt.e%j                        # Output
#SBATCH -J AWSOMR_rt                            # Job name
#SBATCH --time=24:00:00
#####   Job script for the SWMF solar-helio realtime simulation.
#####   C.MERAL 07/2023
#####            
#####   Submit for run with sbatch job.sub
####################################################
# Loading the modules
source /usr/share/Modules/init/bash
module load intel-oneapi-compilers/2024.1.0-gcc-11.4.1-imjimv2
module load openmpi/4.1.6-oneapi-2024.1.0-uqcq2or
export MPICC_CC=icc
export MPICXX_CXX=icpc
#Fix stack size issue
ulimit -s unlimited
SWMF_dir=`pwd`
echo "SWMF dir: $SWMF_dir"
RUNDIR=$SWMF_dir/run_realtime
echo "Run dir: $RUNDIR"
PYTHON3=/usr/local/bin/python3

cd $RUNDIR
mv PARAM.in PARAM.in_`date +%y%m%d_%H%M`
rm -f PARAM.in_orig_
echo "Before restarting real-time simulation remove start magnetogram"
rm -f harmonics_bxyz.out
mv  harmonics_new_bxyz.out harmonics_bxyz.out
echo "Download new magnetogram"
cd $SWMF_dir
python3 get_latest_magnetogram.py
cd $RUNDIR/SC
rm -f STARTMAGNETOGRAMTIME.in PARAM.tmp
rm -f *.fits.gz *.fits harmonics.log* fitsfile_01.out endmagnetogram*
cp ENDMAGNETOGRAMTIME.in STARTMAGNETOGRAMTIME.in
tar -xzvf submission.tgz
mv *.fits endmagnetogram
python3 remap_magnetogram.py endmagnetogram fitsfile
#Calculate the
./HARMONICS.exe |tee harmonics.log_`date +%y%m%d_%H%M`
#Origin Magnetogram becomes endmagnetogram
mv MAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in

#Copy the PARAM.tmp file
cp $SWMF_dir/THREAD/PARAM.in.realtime.restart PARAM.tmp
#Convert it as PARAM.in with the proper start time and include files
$SWMF_dir/share/Scripts/ParamConvert.pl PARAM.tmp ../PARAM.in
#Test the format of  PARAM.in file
cd $SWMF_dir
Scripts/TestParam.pl -F $RUNDIR/PARAM.in
# run SWMF models
cd $RUNDIR
mpiexec -n 324 ./SWMF.exe > runlog_`date +%y%m%d_%H%M`
./PostProc.pl -n=16 #-M -cat RESULTS_`date +%y%m%d_%H%M`
rm -rf RESTART_n* RESTART.in
./Restart.pl -v
cd $SWMF_dir
exit 0
