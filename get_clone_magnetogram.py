#!/usr/bin/env python3
############ Prototype: make_submission.py by Maksym Petrenko
############ CMERAL modification of make_submission.py
############ 30/11/2022
############ This python script correspond to a part of the make_submission.py
############ that only download the latest GONG magnetogram for realtime
############ simulation in the run directory as fitsfile.fits
###############################################################################################################
import re
import os
import shutil
import gzip

#modify to change the output directory
ISWACLONE = '/Users/igorsok/ISWACLONE'
OUTDIR = '/Users/igorsok/SUBMISSION'


def get_highest(page, pattern, datetime):
    last_match = ''
    last_link = ''
    links = os.listdir(page)
    for link in links:
        matches = re.search(pattern, link)
        if (matches):
            if (matches.group(1) > last_match and matches.group(1)<=datetime):
                last_match = matches.group(1)
                last_link = str(link)
    return [last_link]

if __name__ == '__main__':

    datetime = input()
    print(datetime)
    matches=re.search(r'(\d\d\d\d\d\dt\d\d\d\d)',datetime)
    year = '20'+matches.group(1)[0:2]
    month = matches.group(1)[2:4]
    ISWAYEAR=ISWACLONE.rstrip('/') + '/' + str(year)
    ISWAMONTH=ISWAYEAR.rstrip('/') + '/' + str(month)
    
    [link] = get_highest(
        ISWAMONTH,r'(\d\d\d\d\d\dt\d\d\d\d)',matches.group(1))
    granule_url = ISWAMONTH.rstrip('/') + '/' + str(link)
    print("granule_url="+granule_url)
    # Adjust input files
    if not os.path.exists(OUTDIR):
        os.makedirs(OUTDIR)
    fits_file = os.path.join(OUTDIR, "fitsfile.fits")
    fits_file_gz = os.path.join(ISWAMONTH,str(link))
    with gzip.open(fits_file_gz, 'rb') as f_in:
        with open(fits_file, 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)
