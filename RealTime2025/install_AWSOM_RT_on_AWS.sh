#!/bin/bash                                    
#####   Charlotte Meral                           
#####   11/28/2022               
#####   Revision: Igor Sokolov 2025/01/28 : change the compilation option for
#####   default.
#####   This script performs the installation and initialisation process for   
#####   SWMF solar-helio realtime simulation on AWS. It reinstalls SWMF with
#####   the compiler and module needed.
#####   Revision: Zhenguang Huang 2025/01/28. Rename from
#####   run_SWMF_AWSOM_realtime_init.sh
#####   Pay attention to the shell environment (modules, compilers, etc).
####################################################
#
#load correct modules
source /usr/share/Modules/init/bash
module purge
module load intel-oneapi-compilers/2024.1.0-gcc-11.4.1-imjimv2
module load openmpi/4.1.6-oneapi-2024.1.0-uqcq2or
#
#specify compiler
export MPICC_CC=icc
export MPICXX_CXX=icpc
#
SWMF_dir=`pwd`
echo "$SWMF_dir"
#
# Uninstall the code first
#
# ATTENTION: If the directory is started from scratch, do
# ./Config.pl -install
# before calling install_AWSOM_RT_on_AWS.sh for the first time 
./Config.pl -uninstall
#
# Re-install the code                                                           
./Config.pl -install -compiler=ifortmpif90
#
# Install SC and IH
./Config.pl -v=Empty,SC/BATSRUS,IH/BATSRUS
./Config.pl -o=SC:u=Awsom,e=AwsomSA,nG=2,g=6,8,8
# cd SC/BATSRUS; make newtr; cd ${SWMF_dir}
./Config.pl -o=IH:u=Awsom,e=AwsomSA,nG=2,g=8,8,8
#
#
#                                     
#Main executable SWMF.exe brought to update and linked to SWMF_dir/bin
echo "make SWMF"
make -j SWMF
#
#bin/PostIDL.exe will post-processes *.idl files                      
echo "make PIDL"
make PIDL
#
cd ${SWMF_dir}/util/DATAREAD/srcMagnetogram
#
#Compile HARMONICS.exe and links it to SWMF_dir/bin directory
echo "make HARMONICS"
make HARMONICS
#
#Compile CONVERTHARMONICS.exe and links it to SWMF_dir/bin directory
echo "make CONVERTHARMONICS"
make CONVERTHARMONICS
#
cd ${SWMF_dir}
########
#
exit 0
