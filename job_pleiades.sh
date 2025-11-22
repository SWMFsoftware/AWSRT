#!/bin/bash
#PBS -S /bin/bash
#PBS -N SWMF_MFLAMPA_RT
#PBS -W group_list=s2157
#PBS -o /dev/null
#PBS -e /dev/null
# To run on the 28-core Electra Broadwell nodes (128GB/node or 4.5GB/core)
#PBS -l select=16:ncpus=28:model=bro_ele
####################################################
# Loading the modules
source /usr/share/Modules/init/bash
module purge
module load comp-intel/2020.4.304
module load mpi-hpe/mpt.2.30
module load gcc/9.3
module use -a /swbuild/analytix/tools/modulefiles
module load miniconda3/v4
module load cuda/11.0 
module use -a /nasa/modulefiles/testing
module load python3/3.8.8
#Fix stack size issue
ulimit -s unlimited

SWMF_dir=/home4/mpetrenk/MODELS/SH/SWMF_solar/SWMF_MFLAMPA_DEV
POSTPROC_dir=$SWMF_dir/share/Scripts/
RUNDIR=/nobackupp28/isokolov/run_realtime
####Create run_realtime directory####
rm -rf $RUNDIR
mkdir $RUNDIR
######### Pack a copy of the generic run directory
######### to $run_dir/copyrun.tgz   ###############
######### (only subdirectories SC,IH, STDOUT and files *.in are copied)                  
cd $SWMF_dir"/run"
tar -czvf $RUNDIR/copyrun.tgz SC IH SP STDOUT *.in core
cd $RUNDIR
tar -xpzvf copyrun.tgz
rm -f copyrun.tgz
ln -s $SWMF_dir"/bin/SWMF.exe" ./SWMF_solar.exe
ln -s $SWMF_dir"/Param" .
rm -f PostProc.pl
ln -s $POSTPROC_dir/PostProc.pl ./PostProc.pl
rm -f Restart.pl
ln -s $POSTPROC_dir/Restart.pl  ./Restart.pl
cd SC
rm -f Param
ln -s $SWMF_dir"/GM/BATSRUS/Param/CORONA" ./Param
rm -f PostIDL.exe
ln -s $SWMF_dir"/bin/PostIDL.exe" ./PostIDL.exe
cd ../IH
rm -f Param
ln -s $SWMF_dir/GM/BATSRUS/Param/HELIOSPHERE ./Param
rm -f PostIDL.exe
ln -s $SWMF_dir/bin/PostIDL.exe ./PostIDL.exe
cd $RUNDIR/SC
#Modify HARMONICS.in input and output files names and max order set to 30
perl -i -pe 's/dipole11uniform/fitsfile_01/; s/harmonics11uniform/endmagnetogram/; s/\d+(\s+MaxOrder)/180$$1/' HARMONICS.in
perl -i -pe 's/USEMAGNETOGRAMDATE/#USEMAGNETOGRAMDATE/' HARMONICS.in
#Modify HARMONICSGIRD.in magnetogram file name and grid parameters
perl -i -pe 's/harmonics/endmagnetogram/; s/\d+(\s+MaxOrder)/180$$1/; s/\d+(\s+nR)/150$$1/; s/\d+(\s+nLon)/180$$1/; s/\d+(\s+nLat)/90$$1/' HARMONICSGRID.in
#####  Download the most recent GONG magnetogram and produces fits files
python3  $SWMF_dir/AWSRT/get_magnetogram_pleiades.py
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
mpiexec -n 16 ./CONVERTHARMONICS.exe > convert.log_`date +%y%m%d_%H%M`
mv harmonics_bxyz.out ../harmonics_new_bxyz.out
#Copy the PARAM.tmp file
cp $SWMF_dir/AWSRT/PARAM.in.realtime.pleiades PARAM.tmp
#Convert it as PARAM.in with the proper start time and include files
$SWMF_dir/share/Scripts/ParamConvert.pl PARAM.tmp ../PARAM.in
cd $RUNDIR
mpiexec -n 448 ./SWMF_solar.exe > runlog_`date +%y%m%d_%H%M`
./Restart.pl -v
exit 0
