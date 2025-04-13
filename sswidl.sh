#!/bin/tcsh
################# inititalization of the ssw-idl
################# ## 
################# tcsh
################# source AWSRT/sswidl.sh
################# ##
############ Machine-dependedent commands ###########
############ Path to the IDL directory
setenv IDL_DIR /Applications/NV5/idl91/
############ Path to the installed Solar SoftWare (SSW)
setenv SSW $HOME/ssw
setenv SSW_INSTR "gen soho aia hmi xrt eit lasco secchi nrl festival sunspice"
source $SSW/gen/setup/setup.ssw /loud

