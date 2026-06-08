#!/bin/bash

source /usr/share/Modules/init/bash
module use -a /swbuild/analytix/tools/modulefiles
module load miniconda3/v4

###############################################################
# This script advances the time of the magnetogram if it is not
# updated within a specified time window. This can ensure that
# the pipeline is operating even if there is a disruption in 
# the NSO/GONG service. Should be run with cron.

# Author: Gergely Koban
##############################################################

FITS_FILE="/nobackupp28/gkoban/SWMF_AWSRT/SWMF/SUBMISSION_DATA/fitsfile.fits"
PYTHON_SCRIPT="/nobackupp28/gkoban/SWMF_AWSRT/SWMF/fitstime_advance.py"

# Check that the FITS file exists
if [ ! -f "$FITS_FILE" ]; then
    echo "Error: FITS file not found: $FITS_FILE"
    exit 1
fi

# Check that the Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "Error: Python script not found: $PYTHON_SCRIPT"
    exit 1
fi

# Current time and file modification time (seconds since epoch)
now=$(date +%s)
mtime=$(stat -c %Y "$FITS_FILE")

# Age of file in minutes
age_minutes=$(( (now - mtime) / 60 ))

if [ "$age_minutes" -ge 80 ]; then
    echo "$(date): File has not changed in the last 70 minutes (age: ${age_minutes} min). Advancing DATE header."
    python3 "$PYTHON_SCRIPT"
else
    echo "$(date): File was changed recently (age: ${age_minutes} min). Not advancing DATE header."
fi
