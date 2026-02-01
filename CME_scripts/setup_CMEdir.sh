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


exec >> /nobackupp28/gkoban/Realtime/SWMF/output.log 2>&1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cycle)
      CYCLE_DIR="$2"
      shift 2
      ;;
    --rundir)
      RUNDIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check that both were provided
if [[ -z "${CYCLE_DIR:-}" || -z "${RUNDIR:-}" ]]; then
  echo "Usage: $0 --cycle <CYCLE_DIR> --rundir <RUNDIR>"
  exit 1
fi

echo "CYCLE_DIR = $CYCLE_DIR"
echo "RUNDIR     = $RUNDIR"

SWMF_dir=/nobackupp28/gkoban/Realtime/SWMF
POSTPROC_dir=$SWMF_dir/share/Scripts/
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

#copying and linking the RESTART files
cd $RUNDIR
cp -a $CYCLE_DIR/harmonics_bxyz.out $RUNDIR/
cp -a $CYCLE_DIR/harmonics_new_bxyz.out $RUNDIR/

cp -a $CYCLE_DIR/RESTART_n000000 $RUNDIR/
ln -s RESTART_n000000/RESTART.out RESTART.in

cp -a $CYCLE_DIR/SC_cleanup/ENDMAGNETOGRAMTIME.in $RUNDIR/SC/
cp -a $CYCLE_DIR/SC_cleanup/STARTMAGNETOGRAMTIME.in $RUNDIR/SC/
cp -a $CYCLE_DIR/SC_cleanup/endmagnetogram $RUNDIR/SC/
cp -a $CYCLE_DIR/SC_cleanup/endmagnetogram.dat $RUNDIR/SC/
cp -a $CYCLE_DIR/SC/CORONALHEATING.in $RUNDIR/SC/

cd $RUNDIR/SC
rm -rf restartIN
ln -s ../RESTART_n000000/SC restartIN

cd $RUNDIR/IH
rm -rf restartIN
ln -s ../RESTART_n000000/IH restartIN


