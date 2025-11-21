#!/usr/bin/env python3
############ Prototype: make_submission.py by Maksym Petrenko
############ CMERAL modification of make_submission.py
############ 30/11/2022
############ This python script correspond to a part of the make_submission.py
############ that only download the latest GONG magnetogram for realtime
############ simulation in the run directory as fitsfile.fits
###############################################################################################################

from html.parser import HTMLParser
import requests
import re
import os
import shutil
import gzip
import tarfile

INPUT_BASE_PATH = 'SUBMISSION_DATA'

#modify to change the output directory (run_realtime directory used for realtime simulations)
OUTPUT_BASE_PATH = '/nobackupp28/isokolov/run_realtime/SC'

def make_tarfile(output_filename, source_dir):
    with tarfile.open(output_filename, "w:gz") as tar:
        tar.add(source_dir, arcname='.')
        
tmp_path = os.path.join(OUTPUT_BASE_PATH, "tmp")
if os.path.exists(tmp_path):
    shutil.rmtree(tmp_path)
shutil.copytree(INPUT_BASE_PATH, tmp_path)

output_path = os.path.join(OUTPUT_BASE_PATH, "submission.tgz")
make_tarfile(output_path, tmp_path)
shutil.rmtree(tmp_path)
