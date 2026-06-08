#!/bin/bash
#PBS -S /bin/bash
#PBS -N SWMF_MFLAMPA_RT
#PBS -W group_list=s2994
### PBS -o /dev/null
### PBS -e /dev/null
# To run on the 28-core Electra Broadwell nodes (128GB/node or 4.5GB/core)
### PBS -l select=18:ncpus=28:model=bro_ele
#PBS -l select=13:ncpus=40:model=cas_ait
#PBS -q long
###PBS -q R24216227
#PBS -l walltime=25:00:00
############################################################
# Written by Gergely Koban for the realtime time SW pipeline
# Based on the original script by Igor Sokolov
###########################################################
# Loading the modules
source /usr/share/Modules/init/bash
module purge
module load comp-intel/2023.2.1
module load mpi-hpe/mpt.2.30
module load gcc/9.3
module use -a /swbuild/analytix/tools/modulefiles
module load miniconda3/v4
#module load cuda/11.0
#module use -a /nasa/modulefiles/testing
#module load python3/3.8.8
# Fix stack size issue
ulimit -s unlimited

exec >> /nobackupp28/gkoban/SWMF_AWSRT/SWMF/output.log 2>&1

SWMF_dir=/nobackupp28/gkoban/SWMF_AWSRT/SWMF/
RUNDIR=/nobackupp28/gkoban/SWMF_AWSRT/SWMF/run_realtime

# FAILSAFE / CHECKPOINTING
set -u  # error on unset variables; 

CHECKROOT="$RUNDIR/checkpoints"
LASTGOOD="$CHECKROOT/last_good"
mkdir -p "$CHECKROOT"

INPROG="$RUNDIR/.cycle_in_progress"

write_inprog() {
  # args: ck phase
  local ck="$1"
  local phase="$2"
  {
    echo "ck=$ck"
    echo "phase=$phase"
    echo "time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "host=$(hostname)"
    echo "jobid=${PBS_JOBID:-NA}"
  } > "$INPROG"
}

clear_inprog() {
  rm -f "$INPROG"
}

recover_if_needed() {
  # If a previous cycle did not finish cleanly, restore last_good.
  if [ -f "$INPROG" ]; then
    echo "Detected unfinished previous cycle: $INPROG"
    echo "Marker contents:"
    cat "$INPROG" 2>/dev/null || true

    echo "Restoring from last_good..."
    restore_last_good || true

    # Remove marker so we don't restore repeatedly
    rm -f "$INPROG"
  fi
}


timestamp() { date +%y%m%d_%H%M%S; }

checkpoint_save() {
  local tag="$1"
  local d="$CHECKROOT/$tag"
  mkdir -p "$d"

  # Core runtime inputs/state
  cp -a "$RUNDIR/PARAM.in"               "$d/" 2>/dev/null || true
  cp -a "$RUNDIR/PARAM.in_"*             "$d/" 2>/dev/null || true
  cp -a "$RUNDIR/harmonics_bxyz.out"     "$d/" 2>/dev/null || true
  cp -a "$RUNDIR/harmonics_new_bxyz.out" "$d/" 2>/dev/null || true

  # SC timing / magnetogram state
  mkdir -p "$d/SC"
  cp -a "$RUNDIR/SC/STARTMAGNETOGRAMTIME.in" "$d/SC/" 2>/dev/null || true
  cp -a "$RUNDIR/SC/ENDMAGNETOGRAMTIME.in"   "$d/SC/" 2>/dev/null || true
  cp -a "$RUNDIR/SC/MAGNETOGRAMTIME.in"      "$d/SC/" 2>/dev/null || true
  cp -a "$RUNDIR/SC/PARAM.tmp"               "$d/SC/" 2>/dev/null || true
  cp -a "$RUNDIR/SC/CORONALHEATING.in"               "$d/SC/" 2>/dev/null || true

  # Restart directories (adjust patterns if your run uses different names)
  if compgen -G "$RUNDIR/RESTART_*" > /dev/null; then
    cp -a "$RUNDIR/RESTART_"* "$d/" 2>/dev/null || true
  fi
  if [ -d "$RUNDIR/RESTART_n000000" ]; then
    cp -a "$RUNDIR/RESTART_n000000" "$d/" 2>/dev/null || true
  fi
}

mark_last_good() {
  local tag="$1"
  rm -f "$LASTGOOD"
  ln -s "$CHECKROOT/$tag" "$LASTGOOD"
}

restore_last_good() {
  if [ ! -L "$LASTGOOD" ] || [ ! -d "$(readlink -f "$LASTGOOD")" ]; then
    echo "No last_good checkpoint exists; cannot restore safely."
    return 1
  fi
  local d
  d="$(readlink -f "$LASTGOOD")"
  echo "Restoring from last_good: $d"

  cp -a "$d/PARAM.in" "$RUNDIR/" 2>/dev/null
  cp -a "$d/harmonics_bxyz.out" "$RUNDIR/" 2>/dev/null
  cp -a "$d/harmonics_new_bxyz.out" "$RUNDIR/" 2>/dev/null

  mkdir -p "$RUNDIR/SC"
  cp -a "$d/SC/"* "$RUNDIR/SC/" 2>/dev/null

  if compgen -G "$d/RESTART_*" > /dev/null; then
    cp -a "$d/RESTART_"* "$RUNDIR/" 2>/dev/null
  fi
  if [ -d "$d/RESTART_n000000" ]; then
    cp -a "$d/RESTART_n000000" "$RUNDIR/" 2>/dev/null
  fi
}

stash_sc_before_cleanup() {
  local ck="$1"
  local stash="$CHECKROOT/$ck/SC_cleanup"
  mkdir -p "$stash"

  # Must be called from $RUNDIR/SC
  # Copy (do NOT move) the critical timing + param files
  for f in STARTMAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in MAGNETOGRAMTIME.in PARAM.tmp; do
    [ -e "$f" ] && cp -a "$f" "$stash/" 2>/dev/null
  done

  # For bulky outputs that you truly meant to remove, either:
  #   - copy (safer, more disk), or
  #   - move only the ones you were going to rm anyway
  for f in *.fits.gz *.fits harmonics.log* fitsfile_01.out endmagnetogram*; do
    if compgen -G "$f" > /dev/null; then
      mv $f "$stash/" 2>/dev/null
    fi
  done
}

cleanup_checkpoints_keep_last_n() {
  # Keep only the last N cycle_* directories, but never delete the last_good target.
  local keep_n="${1:-48}"

  cd "$CHECKROOT" 2>/dev/null || return 0

  local lg=""
  if [ -L "$LASTGOOD" ]; then
    lg="$(basename "$(readlink -f "$LASTGOOD")")"
  fi

  # List cycle_* newest first; skip last_good target; delete everything after keep_n
  ls -1dt cycle_* 2>/dev/null | awk -v keep="$keep_n" -v lg="$lg" '
    BEGIN{count=0}
    {
      if ($0 == lg) next
      count++
      if (count > keep) print $0
    }' | while read -r old; do
      rm -rf "$old"
    done
}


run_swmf_check_only() {
  # Run SWMF and STOP if it failed, but DON'T restore here.
  # Restoration is intended to happen at the next run/cycle start.
  local runts="$1"

  mpiexec -n 520 ./SWMF_solar.exe > "runlog_${runts}"
  local mpi_rc=$?

  if [ $mpi_rc -ne 0 ] || [ ! -f SWMF.SUCCESS ]; then
    echo "SWMF failed (mpiexec rc=$mpi_rc; SWMF.SUCCESS=$( [ -f SWMF.SUCCESS ] && echo yes || echo no ))"
    echo "Exiting nonzero. (Recommended: next run/cycle-start should restore from last_good.)"
    exit 1
  fi
}

# ORIGINAL SCRIPT LOGIC (with failsafe modifications)

##### Remove stop files
rm -f "$RUNDIR/AWSOMRT.STOP" "$RUNDIR/SC/AWSOMRT.STOP"

##### Send stop time
STOPTIME=$(date -d "23 hours 20 minutes" +%s)

for iDay in 1
do
  for M in AM PM
  do
    for iHour in 1 2 3 4 5 6 7 8 9 10 11 12
    do
      cd "$RUNDIR" || exit 1

      recover_if_needed

      if [ -f "AWSOMRT.STOP" ]; then
        ./PostProc.pl -M -cat RESULTS
        rm -f AWSOMRT.STOP
        exit 0
      fi

      mv PARAM.in "PARAM.in_$(date +%y%m%d_%H%M)"

      # Create a checkpoint BEFORE any destructive operations
      CK="cycle_$(timestamp)"
      write_inprog "$CK" "checkpoint"
      checkpoint_save "$CK"

      # Instead of deleting harmonics_bxyz.out, stash it in the checkpoint
      if [ -f "$RUNDIR/harmonics_bxyz.out" ]; then
        cp "$RUNDIR/harmonics_bxyz.out" "$CHECKROOT/$CK/" 2>/dev/null
      fi

      rm -f harmonics_bxyz.out 2>/dev/null
      mv harmonics_new_bxyz.out harmonics_bxyz.out 2>/dev/null

      cd "$RUNDIR/SC" || exit 1

      # move files into checkpoint stash
      stash_sc_before_cleanup "$CK"

      # Original logic: roll END -> START
      rm -f STARTMAGNETOGRAMTIME.in PARAM.tmp *.fits.gz *.fits 2>/dev/null
      rm -f harmonics.log* fitsfile_01.out endmagnetogram* 2>/dev/null
      mv ENDMAGNETOGRAMTIME.in STARTMAGNETOGRAMTIME.in 2>/dev/null

      python3 "$SWMF_dir/get_magnetogram_pleiades.py"

      cd "$RUNDIR/SC" || exit 1
      tar -xzvf submission.tgz
      mv *.fits endmagnetogram
      python3 remap_magnetogram.py endmagnetogram fitsfile
      ./HARMONICS.exe >"harmonics.log_$(date +%y%m%d_%H%M)"
      mv MAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in

      while [ "$(diff STARTMAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in)" == "" ]
      do
        rm -f ENDMAGNETOGRAMTIME.in

        if [ -f "AWSOMRT.STOP" ]; then
          mv STARTMAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in
          echo "Find AWSOMRT.STOP in $RUNDIR/SC"
          exit 0
        fi

        sleep 300
        python3 "$SWMF_dir/get_magnetogram_pleiades.py"
        cd "$RUNDIR/SC" || exit 1
        tar -xzvf submission.tgz
        mv *.fits endmagnetogram
        python3 remap_magnetogram.py endmagnetogram fitsfile
        ./HARMONICS.exe >"harmonics.log_$(date +%y%m%d_%H%M)"
        mv MAGNETOGRAMTIME.in ENDMAGNETOGRAMTIME.in
      done

      cp "$SWMF_dir/AWSRT/PARAM.in.restart.pleiades" PARAM.tmp
      # Convert it as PARAM.in
      "$SWMF_dir/share/Scripts/ParamConvert.pl" PARAM.tmp ../PARAM.in

      cd "$RUNDIR" || exit 1

      RUNTS="$(date +%y%m%d_%H%M)"
      run_swmf_check_only "$RUNTS"

      ./PostProc.pl -n=16 >"PostProc.log_${RUNTS}"
      cat IH/IO2/sat_earth_*.sat > sat_earth.sat
      cat IH/IO2/sat_sta_*.sat   > sat_sta.sat

      # change this to mv to store RESTART files for fallback;
      # but we already checkpointed RESTART_* above.
      rm -rf RESTART_n000000

      ./Restart.pl -v

      # Only now, after a fully successful cycle including Restart.pl, mark last_good
      mark_last_good "$CK"
      cleanup_checkpoints_keep_last_n 24
      clear_inprog


      CURRENT_TIME=$(date +%s)
      if [ $((STOPTIME-CURRENT_TIME)) -lt 0 ] ; then
        ./PostProc.pl -M -cat RESULTS
        exit 0
      fi
    done
  done
done

./PostProc.pl -M -cat RESULTS
exit 0

