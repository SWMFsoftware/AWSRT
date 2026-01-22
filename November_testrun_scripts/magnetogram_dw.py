#!/usr/bin/env python3
"""
Download GONG MRZQS magnetograms from ISWA.

Modes
-----
A) Range mode (explicit):
   python3 download_gong.py --start "2025-12-01 00:00" --end "2025-12-01 12:00" \
       --out-dir /path/to/magnetograms --manifest magnetograms_manifest.csv

B) Latest mode (no args):
   python3 download_gong.py
   -> downloads the single most recent magnetogram available on ISWA up to "now",
      into default out-dir, and writes default manifest.

Notes
-----
- Download criterion is datetime encoded in filename (file_dt).
- Manifest stores three columns:
    filename, file_datetime (from filename), upload_time (Last-Modified from listing)
"""

from __future__ import annotations

import os
import re
import csv
import argparse
import requests
from datetime import datetime
from urllib.parse import urljoin
from typing import List, Tuple, Optional


BASE_URL = "https://iswa.ccmc.gsfc.nasa.gov/iswa_data_tree/observation/solar/gong/mrzqs/"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
}

# --- Parse Apache "Index of" directory listing ---
# Typical fragment:
#   href="FILENAME">FILENAME</a> ... YYYY-MM-DD HH:MM
ROW_RE = re.compile(
    r'href="(?P<href>[^"]+)".*?>\s*(?P<name>[^<]+)</a>.*?'
    r'(?P<lm>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})',
    re.IGNORECASE
)

# --- Extract datetime from filename ---
# Expected substring like: yymmddtHHMM (e.g., 251201t0014)
FNAME_DT_RE = re.compile(r'(?P<dt>\d{6}t\d{4})', re.IGNORECASE)


def parse_fname_dt(filename: str) -> Optional[datetime]:
    """Extract yymmddtHHMM from filename and return as datetime, else None."""
    m = FNAME_DT_RE.search(filename)
    if not m:
        return None
    try:
        return datetime.strptime(m.group("dt"), "%y%m%dt%H%M")
    except ValueError:
        return None


def list_month(url: str, session: requests.Session) -> List[Tuple[str, datetime, datetime, str]]:
    """
    Return list of (name, file_dt, upload_dt, file_url) for files in a month directory.

    - file_dt: datetime parsed from filename (yymmddtHHMM)
    - upload_dt: "Last modified" datetime shown in the directory listing (YYYY-MM-DD HH:MM)
    """
    r = session.get(url, headers=HEADERS, timeout=60)
    r.raise_for_status()
    html = r.text

    out: List[Tuple[str, datetime, datetime, str]] = []
    for m in ROW_RE.finditer(html):
        name = m.group("name").strip()
        href = m.group("href").strip()

        # Skip parent dir and subdirs
        if name in ("Parent Directory",) or name.endswith("/"):
            continue

        # Upload time (Last-Modified from listing)
        upload_dt = datetime.strptime(m.group("lm"), "%Y-%m-%d %H:%M")

        # File time (from filename)
        file_dt = parse_fname_dt(name)
        if file_dt is None:
            continue

        file_url = urljoin(url, href)
        out.append((name, file_dt, upload_dt, file_url))

    return out


def month_range(start_dt: datetime, end_dt: datetime):
    """Yield (YYYY, MM) for each month overlapping [start_dt, end_dt]."""
    y, m = start_dt.year, start_dt.month
    while (y < end_dt.year) or (y == end_dt.year and m <= end_dt.month):
        yield y, m
        m += 1
        if m == 13:
            m = 1
            y += 1


def prev_month(y: int, m: int) -> Tuple[int, int]:
    """Return (prev_year, prev_month)."""
    m -= 1
    if m == 0:
        return (y - 1, 12)
    return (y, m)


def download_stream(url: str, out_path: str, session: requests.Session):
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with session.get(url, headers=HEADERS, stream=True, timeout=120) as r:
        r.raise_for_status()
        with open(out_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    f.write(chunk)


def should_skip_existing(out_path: str) -> bool:
    """
    Skip if file exists.
    If you want to be stricter about partial files:
      - return (os.path.exists(out_path) and os.path.getsize(out_path) > 0)
    """
    return os.path.exists(out_path)


def write_manifest(manifest_path: str, records: List[Tuple[str, datetime, datetime, str]]):
    os.makedirs(os.path.dirname(manifest_path) or ".", exist_ok=True)
    with open(manifest_path, "w", newline="") as f:
        w = csv.writer(f, delimiter=",")
        w.writerow(["filename", "file_datetime", "upload_time"])
        for name, file_dt, upload_dt, _ in records:
            w.writerow([
                name,
                file_dt.strftime("%Y-%m-%d %H:%M"),
                upload_dt.strftime("%Y-%m-%d %H:%M"),
            ])


def download_between(
    start_dt: datetime,
    end_dt: datetime,
    out_dir: str,
    manifest_path: str,
):
    """
    Download all files whose filename datetime (file_dt) is between start_dt and end_dt (inclusive),
    and write a 3-column CSV manifest:
        filename, file_datetime, upload_time
    """
    if end_dt < start_dt:
        raise ValueError("end_dt must be >= start_dt")

    session = requests.Session()

    records: List[Tuple[str, datetime, datetime, str]] = []

    for y, m in month_range(start_dt, end_dt):
        month_url = f"{BASE_URL}{y}/{m:02d}/"
        try:
            entries = list_month(month_url, session)
        except requests.HTTPError as e:
            print(f"Skipping {month_url}: {e}")
            continue

        for name, file_dt, upload_dt, file_url in entries:
            if start_dt <= file_dt <= end_dt:
                records.append((name, file_dt, upload_dt, file_url))

    records.sort(key=lambda x: x[1])

    write_manifest(manifest_path, records)

    total = len(records)
    for i, (name, file_dt, upload_dt, file_url) in enumerate(records, 1):
        out_path = os.path.join(out_dir, name)

        # (1) Do not redownload already downloaded files
        if should_skip_existing(out_path):
            print(f"[{i}/{total}] exists, skipping: {out_path}")
            continue

        print(f"[{i}/{total}] downloading {name} (file_dt={file_dt}, upload={upload_dt})")
        download_stream(file_url, out_path, session)

    print(f"\nDone. Matched {len(records)} files by filename datetime.")
    print(f"Output dir: {out_dir}")
    print(f"Manifest : {manifest_path}")


def find_most_recent_up_to(now_dt: datetime, session: requests.Session, max_months_back: int = 6
                           ) -> Optional[Tuple[str, datetime, datetime, str]]:
    """
    Find the most recent magnetogram on ISWA with file_dt <= now_dt.
    Searches current month then goes backward up to max_months_back months.
    """
    y, m = now_dt.year, now_dt.month

    best: Optional[Tuple[str, datetime, datetime, str]] = None

    for _ in range(max_months_back):
        month_url = f"{BASE_URL}{y}/{m:02d}/"
        try:
            entries = list_month(month_url, session)
        except requests.HTTPError:
            entries = []

        # Keep only entries not in the future
        candidates = [e for e in entries if e[1] <= now_dt]
        if candidates:
            candidates.sort(key=lambda x: x[1])
            best = candidates[-1]
            break

        y, m = prev_month(y, m)

    return best


def download_latest(now_dt: datetime, out_dir: str, manifest_path: str):
    """
    (2) When called without args: download the single most recent magnetogram up to now_dt.
    Writes a 1-row manifest (plus header).
    """
    session = requests.Session()

    latest = find_most_recent_up_to(now_dt, session)
    if latest is None:
        raise RuntimeError(f"No magnetogram found on ISWA up to {now_dt} (searched back several months).")

    name, file_dt, upload_dt, file_url = latest
    records = [(name, file_dt, upload_dt, file_url)]

    write_manifest(manifest_path, records)

    out_path = os.path.join(out_dir, name)
    if should_skip_existing(out_path):
        print(f"[latest] exists, skipping: {out_path}")
    else:
        print(f"[latest] downloading {name} (file_dt={file_dt}, upload={upload_dt})")
        download_stream(file_url, out_path, session)

    print("\nDone. Latest magnetogram:")
    print(f"  filename : {name}")
    print(f"  file_dt  : {file_dt}")
    print(f"  upload_dt: {upload_dt}")
    print(f"Output dir: {out_dir}")
    print(f"Manifest : {manifest_path}")


def parse_dt_arg(s: str) -> datetime:
    return datetime.strptime(s, "%Y-%m-%d %H:%M")


def main():
    parser = argparse.ArgumentParser(description="Download GONG MRZQS magnetograms from ISWA.")
    parser.add_argument("--start", type=str, help='Start datetime "YYYY-MM-DD HH:MM"')
    parser.add_argument("--end", type=str, help='End datetime "YYYY-MM-DD HH:MM"')
    parser.add_argument("--out-dir", type=str, default="/nobackupp28/gkoban/SWMF_AWSRT/SWMF/magnetograms_local")
    parser.add_argument("--manifest", type=str, default="magnetograms_manifest.csv")
    parser.add_argument("--max-months-back", type=int, default=6,
                        help="When finding the latest file, how many months back to search.")
    args = parser.parse_args()

    # If no args provided at all -> latest mode
    no_time_args = (args.start is None and args.end is None)
    if no_time_args:
        now_dt = datetime.now()
        # Ensure max-months-back is used (via global in finder)
        # Quick way: call download_latest after temporarily wrapping finder parameter.
        # We'll just call it directly and use default max_months_back via function signature by redefining.
        session = requests.Session()
        latest = find_most_recent_up_to(now_dt, session, max_months_back=max(1, args.max_months_back))
        if latest is None:
            raise RuntimeError(f"No magnetogram found on ISWA up to {now_dt} (searched back {args.max_months_back} months).")
        # Reuse the same download logic (but keep session created inside download_latest simple)
        download_latest(now_dt=now_dt, out_dir=args.out_dir, manifest_path=args.manifest)
        return

    # Otherwise require both start and end
    if args.start is None or args.end is None:
        parser.error('For range mode you must provide both --start and --end, or provide neither for "latest" mode.')

    start_dt = parse_dt_arg(args.start)
    end_dt = parse_dt_arg(args.end)

    download_between(
        start_dt=start_dt,
        end_dt=end_dt,
        out_dir=args.out_dir,
        manifest_path=args.manifest,
    )


if __name__ == "__main__":
    main()

