#!/usr/bin/env python3

from astropy.io import fits
from datetime import datetime, timedelta

# Path to your FITS file
fits_path = "/nobackupp28/gkoban/SWMF_AWSRT/SWMF/SUBMISSION_DATA/fitsfile.fits"

# Open FITS file in update mode
with fits.open(fits_path, mode='update') as hdul:
    header = hdul[0].header

    # Read DATE keyword
    date_str = header.get('DATE')
    if date_str is None:
        raise ValueError("No DATE keyword found in FITS header")

    # Parse datetime
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%dT%H:%M:%S")
    except ValueError:
        raise ValueError(f"Invalid DATE format: {date_str}")

    # Add 1 hour
    new_dt = dt + timedelta(hours=1)

    # Write back
    new_date_str = new_dt.strftime("%Y-%m-%dT%H:%M:%S")
    header['DATE'] = new_date_str

    print(f"Updated DATE: {date_str} -> {new_date_str}")
