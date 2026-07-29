#!/usr/bin/env python3
"""
Download the latest available GONG MRZQS magnetogram from the GONG website
and place it into SUBMISSION_DATA as fitsfile.fits.

Search order:
1) UTC tomorrow (covers the earliest timezone: UTC+14)
2) UTC today
3) UTC yesterday, ... back to --days-back

Within a day folder, pick the latest file by max tHHMM.

Author: Gergely Koban

"""

import argparse
import gzip
import re
import shutil
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional, Tuple
from dataclasses import dataclass
import requests

FNAME_RE = re.compile(r'href=["\'](mrzqs\d+t\d{4}c\d+_\d+_\d{3}\.fits\.gz|mrzqs\d+t\d{4}c\d+_\d{3}\.fits\.gz)["\']',
                      re.IGNORECASE)
TIME_RE  = re.compile(r"t(\d{4})", re.IGNORECASE)

DEFAULT_SUBMISSION_DATA = "/nobackupp28/gkoban/SWMF_AWSRT/SWMF/SUBMISSION_DATA"
DEFAULT_DAYS_BACK = 5

HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
}

@dataclass
class LastDownload:
    day_folder: str   # YYYY-MM-DD
    source_file: str  # mrzqs...fits.gz

def parse_magnetogram_datetime_utc(day_folder: str, fname: str) -> Optional[datetime]:
    """
    Build a UTC datetime from day_folder (YYYY-MM-DD) and fname containing tHHMM.
    Returns None if parsing fails.
    """
    m = TIME_RE.search(fname)
    if not m:
        return None
    hhmm = m.group(1)  # "HHMM"
    try:
        base = datetime.strptime(day_folder, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        hh = int(hhmm[:2])
        mm = int(hhmm[2:])
        return base.replace(hour=hh, minute=mm, second=0, microsecond=0)
    except Exception:
        return None

def read_last_download(meta_path: Path) -> Optional[LastDownload]:
    """
    Reads fitsfile.source.txt and extracts day_folder and source_file.
    Returns None if not present or malformed.
    """
    if not meta_path.exists():
        return None
    day_folder = None
    source_file = None
    for line in meta_path.read_text().splitlines():
        if line.startswith("day_folder:"):
            day_folder = line.split(":", 1)[1].strip()
        elif line.startswith("source_file:"):
            source_file = line.split(":", 1)[1].strip()
    if day_folder and source_file:
        return LastDownload(day_folder=day_folder, source_file=source_file)
    return None

# TEMPORARY ONLY: GONG SSL certificate is currently misconfigured.
# Remove verify=False once certificate is fixed.

def get_filenames_from_directory(url: str, timeout: int = 30) -> List[str]:
    r = requests.get(url, headers=HEADERS, timeout=timeout)
    r.raise_for_status()
    return FNAME_RE.findall(r.text)

def extract_time_hhmm(fname: str) -> int:
    m = TIME_RE.search(fname)
    return int(m.group(1)) if m else -1

def pick_latest_file(filenames: List[str]) -> Optional[str]:
    if not filenames:
        return None
    return sorted(filenames, key=lambda f: (extract_time_hhmm(f), f), reverse=True)[0]

def download_to_path(url: str, out_path: Path, timeout: int = 60) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, headers=HEADERS, stream=True, timeout=timeout) as r:
        r.raise_for_status()
        with open(out_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    f.write(chunk)

def gunzip(gz_path: Path, out_path: Path) -> None:
    with gzip.open(gz_path, "rb") as f_in:
        with open(out_path, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)

def iter_candidate_days(now_utc: datetime, days_back: int):
    """
    Yield candidate days in desired order:
    tomorrow, today, yesterday, ... (up to days_back).
    days_back=0 => checks only tomorrow and today.
    """
    # 1) tomorrow (UTC+14 safeguard)
    yield now_utc + timedelta(days=1)
    # 2) today
    yield now_utc
    # 3) go backwards
    for d in range(1, days_back + 1):
        yield now_utc - timedelta(days=d)

def find_latest_available(days_back: int) -> Tuple[str, str, str]:
    now_utc = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)

    last_error = None
    for day in iter_candidate_days(now_utc, days_back):
        yyyymm = day.strftime("%Y%m")
        yymmdd = day.strftime("%y%m%d")
        day_str = day.strftime("%Y-%m-%d")

        dir_url = f"https://nispdata.nso.edu/ftp/QR/zqs/{yyyymm}/mrzqs{yymmdd}/"
        try:
            files = get_filenames_from_directory(dir_url)
            latest = pick_latest_file(files)
            if latest:
                return dir_url, latest, day_str
        except Exception as e:
            last_error = e
            continue

    raise RuntimeError(
        f"No magnetogram files found in (UTC) tomorrow/today and the previous {days_back} days. "
        f"Last error seen: {last_error}"
    )

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--submission-data",
        default=DEFAULT_SUBMISSION_DATA,
        help=f"Path to SUBMISSION_DATA (default: {DEFAULT_SUBMISSION_DATA})",
    )
    ap.add_argument(
        "--days-back",
        type=int,
        default=DEFAULT_DAYS_BACK,
        help=("How many previous UTC days to check AFTER trying tomorrow and today. "
              f"(default: {DEFAULT_DAYS_BACK})"),
    )
    ap.add_argument(
        "--keep-gz",
        action="store_true",
        help="Keep fitsfile.fits.gz (default: delete after extraction).",
    )
    args = ap.parse_args()

    submission_dir = Path(args.submission_data)
    submission_dir.mkdir(parents=True, exist_ok=True)

    dir_url, fname, day_str = find_latest_available(args.days_back)
    file_url = dir_url + fname

    gz_path = submission_dir / "fitsfile.fits.gz"
    fits_path = submission_dir / "fitsfile.fits"
    meta_path = submission_dir / "fitsfile.source.txt"

    # --- NEW: only download if it's newer than what we already have ---
    candidate_dt = parse_magnetogram_datetime_utc(day_str, fname)

    last = read_last_download(meta_path)
    last_dt = None
    if last is not None:
        last_dt = parse_magnetogram_datetime_utc(last.day_folder, last.source_file)

    if candidate_dt is not None and last_dt is not None and candidate_dt <= last_dt:
        print("SKIP: website 'latest' appears older than already downloaded magnetogram.")
        print(f"  last:      {last_dt.isoformat()}  ({last.day_folder} / {last.source_file})")
        print(f"  candidate: {candidate_dt.isoformat()}  ({day_str} / {fname})")
        print("  (Keeping existing fitsfile.fits)")
        return 0

    download_to_path(file_url, gz_path)
    gunzip(gz_path, fits_path)

    meta_path.write_text(
        f"download_time_utc: {datetime.now(timezone.utc).isoformat()}\n"
        f"day_folder: {day_str}\n"
        f"source_dir: {dir_url}\n"
        f"source_file: {fname}\n"
        f"source_url: {file_url}\n"
    )

    if not args.keep_gz:
        try:
            gz_path.unlink()
        except FileNotFoundError:
            pass

    print(f"OK: wrote {fits_path}")
    print(f"Source: {file_url}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

