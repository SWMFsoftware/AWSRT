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
import argparse

ISWA_DATA_URL = 'https://iswaa-webservice1.ccmc.gsfc.nasa.gov/iswa_data_tree/observation/solar/gong/mrzqs/'

#modify to change the output directory
ISWACLONE = '/home4/isokolov/ISWACLONE'

HEADERS = {"User-Agent":"Mozilla/5.0 (Macintosh Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.71 Safari/537.36"}


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
        
def download_file(url, save_path):
    try:
        # Send GET request to the URL
        response = requests.get(url)
        # Check if the request was successful (status code 200)
        if response.status_code == 200:
            # Write the content of the response to a local file
            with open(save_path, 'wb') as file:
                file.write(response.content)
        else:
            exit
    except Exception as e:
        exit
        
def get_highest(page_url, pattern, datetimemin, datetimemax, monthclone):
    response = requests.get(page_url)
    page_html = response.text
    link_parser = LinkScrape()
    link_parser.feed(page_html)
    links = link_parser.links
    link_parser.clean()

    for link in links:
        original_url = link['href']
        text = link['text']
        matches = re.search(pattern, text)
        if (matches):
            if (matches.group(1) >= datetimemin and matches.group(1)<=datetimemax):                
                granule_url = page_url.rstrip('/') + '/' + original_url
                fits_file_gz = os.path.join(monthclone,str(original_url))
                if not os.path.exists(fits_file_gz):
                    download_file(granule_url,fits_file_gz)

if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        description=
        "Use python3 clone_iswa_gong.py datetimemin datetimemax")
    parser.add_argument('datetimemin', help=
                        "Date&Time Min in the format yymmdd't'hhmm")
    parser.add_argument('datetimemax', help=
                        "Date&Time Max in the format yymmdd't'hhmm")
    args = parser.parse_args()
    datetimemin = str(args.datetimemin)
    matchesmin=re.search(r'(\d\d\d\d\d\dt\d\d\d\d)',datetimemin)
    datetimemax = str(args.datetimemax)
    matchesmax=re.search(r'(\d\d\d\d\d\dt\d\d\d\d)',datetimemax)
    year = '20'+matchesmin.group(1)[0:2]
    month = matchesmin.group(1)[2:4]
    month_url = ISWA_DATA_URL.rstrip('/')+'/'+\
        str(year)+'/'+str(month)+'/'
    if not os.path.exists(ISWACLONE):
        os.makedirs(ISWACLONE)
    ISWAYEAR=ISWACLONE.rstrip('/') + '/' + str(year)
    if not os.path.exists(ISWAYEAR):
        os.makedirs(ISWAYEAR)
    ISWAMONTH=ISWAYEAR.rstrip('/') + '/' + str(month)
    if not os.path.exists(ISWAMONTH):
        os.makedirs(ISWAMONTH)
    get_highest(
        month_url,r'(\d\d\d\d\d\dt\d\d\d\d)',
        matchesmin.group(1), matchesmax.group(1),ISWAMONTH)
