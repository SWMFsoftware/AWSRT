#!/bin/bash
#PBS -S /bin/bash
#PBS -N SWMF_MFLAMPA_RT
#PBS -W group_list=s2157
#PBS -o /dev/null
#PBS -e /dev/null
# To run on the 28-core Electra Broadwell nodes (128GB/node or 4.5GB/core)
#PBS -l select=16:ncpus=28:model=bro_ele
#PBS -q long
#PBS -l walltime=25:00:00 
####################################################
# Loading the modules
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
RUNDIR=/nobackupp28/isokolov/run_realtime
#
##### Remove stop files
rm -f $RUNDIR/AWSOMRT.STOP $RUNDIR/SC/AWSOMRT.STOP
##### Send stop time
STOPTIME=$(date -d "23 hours 20 minutes" +%s)
for iDay in 1 2
do
    for M in AM PM
    do
	for iHour in 1 2 3 4 5 6 7 8 9 10 11 12
	do
	    cd $RUNDIR
	    if [ -f "AWSOMRT.STOP" ]; then
		./PostProc.pl -M -cat RESULTS
		rm -f AWSOMRT.STOP
		exit 0
	    fi
	    mv PARAM.in PARAM.in_`date +%y%m%d_%H%M`
	    rm -f harmonics_bxyz.out
	    mv  harmonics_new_bxyz.out harmonics_bxyz.out
	    cd $RUNDIR/SC
	    rm -f STARTMAGNETOGRAMTIME.in PARAM.tmp *.fits.gz *.fits
	    rm -f harmonics.log* fitsfile_01.out endmagnetogram*
	    mv ENDMAGNETOGRAMTIME.in STARTMAGNETOGRAMTIME.in
	    python3  $SWMF_dir/AWSRT/get_magnetogram_pleiades.py
	    cd $RUNDIR/SC
	    tar -xzvf submission.tgz
	    mv *.fits endmagnetogram
	    python3 remap_magnetogram.py endmagnetogram fitsfile
	    ./HARMONICS.exe >harmonics.log_`date +%y%m%d_%H%M`
	    mv MAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in
	    while [ "$( diff STARTMAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in )" == "" ]
	    do
		rm -f ENDMAGNETOGRAMTIME.in
		if [ -f "AWSOMRT.STOP" ]; then
		    mv STARTMAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in
		    echo "Find AWSOMRT.STOP in $RUNDIR/SC"
		    exit 0
		fi
		sleep 300
		python3  $SWMF_dir/AWSRT/get_magnetogram_pleiades.py
		cd $RUNDIR/SC
		tar -xzvf submission.tgz
		mv *.fits endmagnetogram
		python3 remap_magnetogram.py endmagnetogram fitsfile
		./HARMONICS.exe >harmonics.log_`date +%y%m%d_%H%M`
		mv MAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in
	    done
	    cp $SWMF_dir/AWSRT/PARAM.in.restart.pleiades PARAM.tmp
	    #Convert it as PARAM.in
	    $SWMF_dir/share/Scripts/ParamConvert.pl PARAM.tmp ../PARAM.in
	    cd $RUNDIR
	    mpiexec -n 448 ./SWMF_solar.exe > runlog_`date +%y%m%d_%H%M`
	    if [ ! -f SWMF.SUCCESS ]; then
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
	    CURRENT_TIME=$(date +%s)
	    if [ $(($STOPTIME-$CURRENT_TIME)) -lt 0 ] ; then
		./PostProc.pl -M -cat RESULTS
		exit 0
	    fi
	done
    done
done
./PostProc.pl -M -cat RESULTS
exit 0
