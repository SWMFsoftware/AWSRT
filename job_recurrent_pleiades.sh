#!/bin/tcsh

### SWMF solar-helio realtime simulation
### Gergely Koban for Pleiades
### Based on work from Igor Sokolov
###########################################

#PBS -S /bin/tcsh
#PBS -N AWSRT
#PBS -l select=8:ncpus=40:model=sky_ele
### PBS -q long
### PBS -q devel
#PBS -l walltime=6:30:00
#PBS -j oe
#PBS -m e
#PBS -W group_list=s2994
# cd $PBS_O_WORKDIR
# For PGI compilers uncomment the 3 lines below
#module purge; module load comp-pgi mpi-hpe idl python
#setenv MPICC_CC pgcc
#setenv MPICXX_CXX pgc++>
setenv MPI_TYPE_DEPTH 20


####################################################
# Loading the modules
source /usr/share/Modules/init/tcsh
###module purge

setenv MODULES_VERBOSITY concise
module load comp-intel gcc/9.3 mpi-hpe/mpt idl

setenv MPICC icc
setenv MPICXX_CXX icpc

alias rm /bin/rm -i                     # prompting remove
alias mv /bin/mv -i                     # prompting move
alias cp /bin/cp -i                     # prompting copy

module use -a /swbuild/analytix/tools/modulefiles
module load miniconda3/v4

#Fix stack size issue
#ulimit -s unlimited

setenv SWMF_dir /nobackupp28/gkoban/SWMF_AWSRT/SWMF
setenv RUNDIR ${SWMF_dir}/run_realtime
### echo "SWMF dir: $SWMF_dir" >> $RUNDIR/debug.log
### echo "Run dir: $RUNDIR" >> $RUNDIR/debug.log

#
##### Remove stop files
rm -f $RUNDIR/AWSOMRT.STOP $RUNDIR/SC/AWSOMRT.STOP 

foreach iDay ( 1 2 3 4 5 6 7 )
    foreach M ( AM PM )
        foreach iHour ( 1 2 3 4 5 6 7 8 9 10 11 12 )
            cd $RUNDIR

            # Check for STOP file
            if ( -f AWSOMRT.STOP ) then
                ./PostProc.pl -M -cat RESULTS_`date +%y%m%d_%H%M`
		### echo "Find AWSOMRT.STOP in $RUNDIR"  >> $RUNDIR/debug.log
                exit 0
            endif

            mv PARAM.in PARAM.in_`date +%y%m%d_%H%M`
            rm -f PARAM.in_orig_
            rm -f harmonics_bxyz.out
            mv harmonics_new_bxyz.out harmonics_bxyz.out

            cd $RUNDIR/SC
            rm -f STARTMAGNETOGRAMTIME.in PARAM.tmp *.fits.gz *.fits
            rm -f harmonics.log* fitsfile_01.out endmagnetogram*
            mv -f ENDMAGNETOGRAMTIME.in STARTMAGNETOGRAMTIME.in

	    cp $SWMF_dir/SUBMISSION_DATA/fitsfile.fits $RUNDIR/SC/fitsfile.fits
            cd $RUNDIR/SC
            mv *.fits endmagnetogram

            python3 remap_magnetogram.py endmagnetogram fitsfile

            ./HARMONICS.exe > harmonics.log_`date +%y%m%d_%H%M`
            mv MAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in

	   	
            # While the diff is empty
            while ( "`diff STARTMAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in`" == "" )
                # STOP file check
                if ( -f AWSOMRT.STOP ) then
                    rm -f ENDMAGNETOGRAMTIME.in
                    mv STARTMAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in
		    ### echo "Find AWSOMRT.STOP in $RUNDIR/SC"  >> $RUNDIR/debug.log
                    exit 0
                endif

		sleep 300
		
		cp $SWMF_dir/SUBMISSION_DATA/fitsfile.fits $RUNDIR/SC/fitsfile.fits

                cd $RUNDIR/SC
                mv *.fits endmagnetogram

                python3 remap_magnetogram.py endmagnetogram fitsfile

                ./HARMONICS.exe > harmonics.log_`date +%y%m%d_%H%M`
                mv MAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in
            end

            cp -f $SWMF_dir/AWSRT/PARAM.in.realtime.restart PARAM.tmp

            # Convert PARAM.tmp to PARAM.in
            $SWMF_dir/share/Scripts/ParamConvert.pl PARAM.tmp ../PARAM.in

            # Test PARAM.in
            cd $SWMF_dir
            Scripts/TestParam.pl -F $RUNDIR/PARAM.in

            cd $RUNDIR
	    ### echo "This is when the simulation starts"  >> $RUNDIR/debug.log
	    mpiexec -n 128 ./SWMF.exe > runlog_`date +%y%m%d_%H%M`

            if ( ! -f SWMF.SUCCESS ) then
                rm -f harmonics_new_bxyz.out
                mv harmonics_bxyz.out harmonics_new_bxyz.out
                rm -f SC/ENDMAGNETOGRAMTIME.in
                mv SC/STARTMAGNETOGRAMTIME.in SC/ENDMAGNETOGRAMTIME.in
                exit 0
            endif

            ./PostProc.pl -n=16 > PostProc.log_`date +%y%m%d_%H%M`

            cat IH/IO2/sat_earth_*.sat > sat_earth.sat
            cat IH/IO2/sat_sta_*.sat > sat_sta.sat

            rm -rf RESTART_n000000

            ./Restart.pl -v

        end
    end
end

./PostProc.pl -M -cat RESULTS_`date +%y%m%d_%H%M`

exit 0
