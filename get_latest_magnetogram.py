#!/usr/bin/env python3
############ Prototype: make_submission.py by Maksym Petrenko
############ CMERAL modification of make_submission.py
############ 30/11/2022
############ This python script correspond to a part of the make_submission.py
############ that only download the latest GONG magnetogram for realtime
############ simulation in the run directory as fitsfile.fits
###############################################################################################################

from html.parser import HTMLParser
import itertools
import re
import os
import shutil
import urllib.request
import gzip
import tarfile

ISWA_DATA_URL = 'https://iswaa-webservice1.ccmc.gsfc.nasa.gov/iswa_data_tree/observation/solar/gong/mrzqs/'
INPUT_BASE_PATH = 'SUBMISSION_DATA'

#modify to change the output directory (run_realtime directory used for realtime simulations)
OUTPUT_BASE_PATH = 'run_realtime/SC'

HEADERS = {"User-Agent":"Mozilla/5.0 (Macintosh Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.71 Safari/537.36"}


def make_tarfile(output_filename, source_dir):
    with tarfile.open(output_filename, "w:gz") as tar:
        tar.add(source_dir, arcname='.')



class LinkScrape(HTMLParser):
    def reset(self):
        super().reset()
        self.links = []
        self.in_link = False
    def handle_starttag(self, tag, attrs):
        self.in_link = False
        if tag == 'a':
            self.in_link = True
            for (name, value) in attrs:
                if name == 'href':
                    self.links.append({'href': value})
    def handle_endtag(self, attrs):
        self.in_link = False
    def handle_data(self, data):
        if self.in_link: self.links[-1]['text'] = data
    def clean(self):
        self.links = []


def get_highest(page_url, pattern):
    global HEADERS
    request = urllib.request.Request(page_url, headers=HEADERS)

    try:
        response = urllib.request.urlopen(request)
        page_html = response.read().decode("utf8")
    except:
        print("Failed to download magnetogram")
        exit


    link_parser = LinkScrape()
    link_parser.feed(page_html)
    links = link_parser.links
    link_parser.clean()


    last_match = ''
    lats_link = ''
    last_text = ''
    for link in links:
        original_url = link['href']
        text = link['text']
        matches = re.search(pattern, text)
        if (matches):
            if (matches.group(1) > last_match):
                last_match = matches.group(1)
                lats_link = original_url
                last_text = text
    return [last_match, last_text, lats_link]


# Fetch magnetogram data
[year, year_text, year_link] = get_highest(ISWA_DATA_URL, r'(\d\d\d\d)')
year_url = ISWA_DATA_URL.rstrip('/') + '/' + year_link.rstrip('/') + '/'
[month, month_text, month_link] = get_highest(year_url, r'(\d\d)')
month_url = year_url.rstrip('/') + '/' + month_link.rstrip('/') + '/'
[cr, cr_text, cr_link] = get_highest(month_url, r'(\d\d\d\d\d\dt\d\d\d\dc\d\d\d\d)')
granule_url = month_url.rstrip('/') + '/' + cr_link

# Copy template files
if not os.path.exists(OUTPUT_BASE_PATH):
    os.makedirs(OUTPUT_BASE_PATH)

tmp_path = os.path.join(OUTPUT_BASE_PATH, "tmp")
if os.path.exists(tmp_path):
    shutil.rmtree(tmp_path)
shutil.copytree(INPUT_BASE_PATH, tmp_path)

# Adjust input files
fits_file = os.path.join(tmp_path, "fitsfile.fits")
fits_file_gz = os.path.join(tmp_path, "fitsfile.fits.gz")

urllib.request.urlretrieve(granule_url, fits_file_gz)

#urllib.request.urlretrieve(granule_url)

with gzip.open(fits_file_gz, 'rb') as f_in:
    with open(fits_file, 'wb') as f_out:
        shutil.copyfileobj(f_in, f_out)
os.unlink(fits_file_gz)

output_path = os.path.join(OUTPUT_BASE_PATH, "submission.tgz")
make_tarfile(output_path, tmp_path)
shutil.rmtree(tmp_path)
