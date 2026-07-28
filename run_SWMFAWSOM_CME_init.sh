#!/bin/bash
####################################################
SWMF_dir=`pwd`
echo "$SWMF_dir"
module purge
module load comp-intel
module load mpi-hpe/mpt
module load gcc/9.3
cd CLEAR; make install; cd ../
./Config.pl -uninstall
HOME=/home6/sofieops
export HOME
./Config.pl -install -compiler=ifortmpif90,iccmpicxx
cd CLEAR; make install; cd ../
./Config.pl -v=Empty,IH/BATSRUS,SC/BATSRUS,SP/MFLAMPA
./Config.pl -o=SC:u=AwsomR,e=AwsomSA,ng=2,g=8,8,4
./Config.pl -o=IH:u=AwsomR,e=AwsomSA,ng=2,g=4,4,4
./Config.pl -o=SP:g=20000
./Config.pl -s
make GITINFO=NO -j
cd $SWMF_dir/PT/MITTENS; make -j; cd $SWMF_dir
make PIDL
make td_compile
rm -rf run
make rundir
exit 0
