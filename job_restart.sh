#!/bin/bash      
#SBATCH -n 192                                  # Number of tasks
#SBATCH -o AWSOMR_rt.o%j                        # Output
#SBATCH -e AWSOMR_rt.e%j                        # Output
#SBATCH -J AWSOMR_rt                            # Job name
#SBATCH --time=180:00:00
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
#
##### Remove stop files
rm -f $RUNDIR/AWSOMRT.STOP $RUNDIR/SC/AWSOMRT.STOP 
for iDay in 1 2 3 4 5 6 7
do
    for M in AM PM
    do
	for iHour in 1 2 3 4 5 6 7 8 9 10 11 12
	do
	    cd $RUNDIR
	    if [ -f "AWSOMRT.STOP" ]; then
		./PostProc.pl -M -cat RESULTS_`date +%y%m%d_%H%M`
		echo "Find AWSOMRT.STOP in $RUNDIR"
		exit 0
	    fi
	    mv PARAM.in PARAM.in_`date +%y%m%d_%H%M`
	    rm -f PARAM.in_orig_
	    rm -f harmonics_bxyz.out
	    mv  harmonics_new_bxyz.out harmonics_bxyz.out
	    cd $RUNDIR/SC
	    rm -f STARTMAGNETOGRAMTIME.in PARAM.tmp *.fits.gz *.fits
	    rm -f harmonics.log* fitsfile_01.out endmagnetogram*
	    mv ENDMAGNETOGRAMTIME.in STARTMAGNETOGRAMTIME.in
	    cd $SWMF_dir
	    python3 get_latest_magnetogram.py
	    cd $RUNDIR/SC
	    tar -xzvf submission.tgz
	    mv *.fits endmagnetogram
	    python3 remap_magnetogram.py endmagnetogram fitsfile
	    ./HARMONICS.exe >harmonics.log_`date +%y%m%d_%H%M`
	    mv MAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in
	    if [ "$( diff STARTMAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in )" == "" ]
	    then
		./PostProc.pl -M -cat RESULTS_`date +%y%m%d_%H%M`
		echo "Simulation system chased real time"
		exit 0
	    fi
	    cp $SWMF_dir/AWSRT/PARAM.in.realtime.restart PARAM.tmp
	    #Convert it as PARAM.in
	    $SWMF_dir/share/Scripts/ParamConvert.pl PARAM.tmp ../PARAM.in
	    #Test the format of  PARAM.in file
	    cd $SWMF_dir
	    Scripts/TestParam.pl -F $RUNDIR/PARAM.in
	    cd $RUNDIR
	    mpiexec -n 192 ./SWMF.exe > runlog_`date +%y%m%d_%H%M`
	    if [ !-f SWMF.SUCCESS ]; then
		rm -f harmonics_new_bxyz.out
		mv harmonics_bxyz.out harmonics_new_bxyz.out
		rm -f SC/ENDMAGNETOGRAMTIME.in
		mv SC/STARTMAGNETOGRAMTIME.in SC/ENDMAGNETOGRAMTIME.in
		exit 0
	    fi
	    ./PostProc.pl -n=16 >PostProc.log_`date +%y%m%d_%H%M`
	    cat IH/IO2/sat_earth_*.sat>sat_earth.sat
	    cat IH/IO2/sat_sta_*.sat>sat_sta.sat
	    rm -rf RESTART_n000000
	    ./Restart.pl -v
	done
    done
done
./PostProc.pl -M -cat RESULTS_`date +%y%m%d_%H%M`
exit 0
