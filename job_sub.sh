#!/bin/bash      
#SBATCH -n 256                                  # Number of tasks
#SBATCH -o AWSOMR_rt.o%j                        # Output
#SBATCH -e AWSOMR_rt.e%j                        # Output
#SBATCH -J AWSOMR_rt                            # Job name
#SBATCH --time=24:00:00
#####   SWMF solar-helio realtime simulation, steady-state
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
####Create run_realtime directory####
rm -rf run_realtime
make rundir RUNDIR=$SWMF_dir/run_realtime

cd $RUNDIR/SC
#Modify HARMONICS.in input and output files names and max order set to 30
perl -i -pe 's/dipole11uniform/fitsfile_01/; s/harmonics11uniform/endmagnetogram/; s/\d+(\s+MaxOrder)/180$$1/' HARMONICS.in
###
### 2025.03.08 Temporary fix for the incorrect CRNOW parameter
###
perl -i -pe 's/USEMAGNETOGRAMDATE/#USEMAGNETOGRAMDATE/' HARMONICS.in
###
#Modify HARMONICSGIRD.in magnetogram file name and grid parameters
perl -i -pe 's/harmonics/endmagnetogram/; s/\d+(\s+MaxOrder)/180$$1/; s/\d+(\s+nR)/150$$1/; s/\d+(\s+nLon)/180$$1/; s/\d+(\s+nLat)/90$$1/' HARMONICSGRID.in
#####  Download the most recent GONG magnetogram and produces fits files
cd $SWMF_dir
python3 get_latest_magnetogram.py

#Copy the file in run_realtime/SC and expand it to create fitsfile
cd $RUNDIR/SC
tar -xzvf submission.tgz

mv *.fits endmagnetogram
python3 remap_magnetogram.py endmagnetogram fitsfile
#Calculate the field harmonics needed to run the SWMF with fitsfile.out
./HARMONICS.exe >harmonics.log_`date +%y%m%d_%H%M`
#Origin Magnetogram becomes endmagnetogram
mv MAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in

#Convert harmonics
mpiexec -n 8 ./CONVERTHARMONICS.exe > convert.log_`date +%y%m%d_%H%M`
mv harmonics_bxyz.out ../harmonics_new_bxyz.out

#Copy the PARAM.tmp file
cp $SWMF_dir/AWSRT/PARAM.in.realtime.SCIH_threadbc PARAM.tmp
#Convert it as PARAM.in with the proper start time and include files
$SWMF_dir/share/Scripts/ParamConvert.pl PARAM.tmp ../PARAM.in
#Test the format of  PARAM.in file
cd $SWMF_dir
Scripts/TestParam.pl -F $RUNDIR/PARAM.in

# run SWMF models
cd $RUNDIR
mpiexec -n 256 ./SWMF.exe > runlog_`date +%y%m%d_%H%M`
./Restart.pl -v
cd $SWMF_dir
exit 0
