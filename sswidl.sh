#!/bin/tcsh
################# inititalization of the ssw-idl
################# ## 
################# tcsh (if in bash)
################# source AWSRT/sswidl.sh
################# ##
############ Machine-dependedent commands ###########
############ Path to the IDL directory
setenv IDL_DIR /nasa/idl/toss4/8.9/idl89
############ Path to SWMF/IDL routines
setenv IDL_PATH "/home4/mpetrenk/MODELS/SH/SWMF_solar/SWMF_MFLAMPA_DEV/share/IDL/General:<IDL_DEFAULT>"
############ Path to the installed Solar SoftWare (SSW)
setenv SSW $HOME/ssw
setenv SSW_INSTR "gen soho aia hmi xrt eit lasco secchi nrl festival sunspice"
source $SSW/gen/setup/setup.ssw /loud

