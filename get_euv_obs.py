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
import argparse

ISWA_DATA_URL = 'https://iswaa-webservice1.ccmc.gsfc.nasa.gov/iswa_data_tree/observation/solar/sdo/'
list_aia=["aia-0131_1024x1024", "aia-0171_2048x2048", "aia-0193_1024x1024", "aia-0211_2048x2048",
          "aia-0335_2048x2048", "aia-0211-193-0171_2048x2048" ]
line_list=["131","171","193","211","335","3_Lines"]

#modify to change the output directory (run_realtime directory used for realtime simulations)
OUTPUT_BASE_PATH = 'TMP'

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


def get_highest(page_url, pattern, datetime):
    response = requests.get(page_url)
    page_html = response.text
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
            if (matches.group(1) > last_match and matches.group(1)<=datetime):
                last_match = matches.group(1)
                lats_link = original_url
                last_text = text
    return [last_match, last_text, lats_link]

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

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="This routine fetches the EUV observation")
    parser.add_argument('inputfile', help='Input synthetic EUV image file')
    args = parser.parse_args()
    inputfile = str(args.inputfile)
    print("Input file name="+str(inputfile))
    myfile = os.path.basename(inputfile)
    print("myfile="+str(myfile))
    matches=re.search(r'(\d\d\d\d\d\d\d\d_\d\d\d\d\d\d)',myfile)
    print("Date_Time=",matches.group(1))
    year = matches.group(1)[0:4]
    month = matches.group(1)[4:6]
    print("Year=",str(year))
    print("Month="+str(month))
    for i in range(6):
        month_url = ISWA_DATA_URL.rstrip('/')+'/'+\
            list_aia[i]+'/'+str(year)+'/'+str(month)+'/'
        print("month_url="+str(month_url))
        [cr, text, link] = get_highest(
            month_url,r'(\d\d\d\d\d\d\d\d_\d\d\d\d\d\d)',str(matches.group(1)))
        granule_url = month_url.rstrip('/') + '/' + link
        print("granule_url="+str(granule_url))
        if not os.path.exists(OUTPUT_BASE_PATH):
            os.makedirs(OUTPUT_BASE_PATH)
        jpg_file = os.path.join(OUTPUT_BASE_PATH, "AIA_"+line_list[i]+".jpg")
        print("jpg_file="+jpg_file)
        download_file(granule_url,jpg_file)

exit

