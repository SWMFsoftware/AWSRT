#!/bin/tcsh
################# inititalization of the ssw-idl
################# can be put to $HOME/.local/bin/sswidl.sh
################# in this case the command
################# source ~/.local/bin/sswidl.sh alllows to
################# use command sswidl in the command line
############ Machine-dependedent command:
############ Path to the IDL directory
setenv IDL_DIR /Applications/NV5/idl91/
############ Path to SWMF/IDL routines
setenv IDL_PATH "${HOME}/SWMF_NO_HISTORY/share/IDL/General:<IDL_DEFAULT>"
############ Path to the installed Solar SoftWare (SSW)
setenv SSW $HOME/ssw
setenv SSW_INSTR "gen soho aia hmi xrt eit lasco secchi nrl festival sunspice"
source $SSW/gen/setup/setup.ssw /loud
exit 0
