#!/usr/bin/env python3
import sys
import csv
import os
import gzip
import shutil
from pathlib import Path
from datetime import datetime

# =========================
# CONFIGURATION (edit here)
# =========================
SWMF_DIR = Path("/nobackupp28/gkoban/Realtime/SWMF")

MANIFEST_PATH = SWMF_DIR / "magnetograms_manifest.csv"
MAGNETOGRAM_DIR = SWMF_DIR / "magnetograms"
SUBMISSION_DATA_DIR = SWMF_DIR / "SUBMISSION_DATA"
OUTPUT_FITS_NAME = "fitsfile.fits"
# =========================


def parse_dt(s: str) -> datetime:
    """Parse datetime from manifest or command line."""
    s = s.strip()
    for fmt in (
        "%Y-%m-%d %H:%M",
        "%Y-%m-%dT%H:%M",
        "%Y-%m-%dT%H:%M:%S",
    ):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    raise ValueError(f"Could not parse datetime: {s}")


def read_manifest(path: str):
    """
    New manifest format (CSV with header):
      filename,file_datetime,upload_time

    Returns sorted list of:
      (filename, file_dt, upload_dt)

    Sort order: by file_dt ascending (so we can break early in picker).
    """
    rows = []
    with open(path, "r", newline="") as f:
        reader = csv.reader(f, delimiter=",")

        for row in reader:
            if not row:
                continue

            # Skip header row if present
            if row[0].strip().lower() == "filename":
                continue

            # Expect at least 3 columns: filename, file_datetime, upload_time
            if len(row) < 3:
                continue

            filename = row[0].strip()
            file_dt = parse_dt(row[1])
            upload_dt = parse_dt(row[2])

            rows.append((filename, file_dt, upload_dt))

    if not rows:
        raise RuntimeError("Manifest file is empty (or no valid data rows found).")

    rows.sort(key=lambda x: x[1])  # sort by file_dt
    return rows


def pick_latest_leq(rows, target_dt: datetime):
    """
    Pick the magnetogram with the latest FILE datetime <= target_dt.
    rows elements are (filename, file_dt, upload_dt), sorted by file_dt.
    """
    best = None
    for filename, file_dt, upload_dt in rows:
        if file_dt <= target_dt:
            best = (filename, file_dt, upload_dt)
        else:
            break
    return best


def gunzip_to_fits(src_gz: str, dst_fits: str):
    os.makedirs(os.path.dirname(dst_fits) or ".", exist_ok=True)
    with gzip.open(src_gz, "rb") as f_in:
        with open(dst_fits, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)


def main():
    if len(sys.argv) != 2:
        print(
            "Usage:\n"
            "  python get_magnetogram_offline.py \"YYYY-MM-DD HH:MM\"\n"
            "  python get_magnetogram_offline.py \"YYYY-MM-DDTHH:MM\"",
            file=sys.stderr
        )
        sys.exit(2)

    try:
        target_dt = parse_dt(sys.argv[1])
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(2)

    try:
        rows = read_manifest(MANIFEST_PATH)
    except Exception as e:
        print(f"ERROR reading manifest '{MANIFEST_PATH}': {e}", file=sys.stderr)
        sys.exit(2)

    chosen = pick_latest_leq(rows, target_dt)

    if chosen is None:
        earliest_file_dt = rows[0][1]
        print(
            f"ERROR: No magnetogram file_datetime <= {target_dt}\n"
            f"Earliest available file_datetime: {earliest_file_dt}",
            file=sys.stderr
        )
        sys.exit(1)

    filename, file_dt, upload_dt = chosen
    src_gz = os.path.join(MAGNETOGRAM_DIR, filename)

    if not os.path.exists(src_gz):
        print(
            f"ERROR: Selected file not found locally:\n  {src_gz}\n"
            f"(Manifest says file_datetime={file_dt}, upload_time={upload_dt})",
            file=sys.stderr
        )
        sys.exit(1)

    os.makedirs(SUBMISSION_DATA_DIR, exist_ok=True)
    dst_fits = os.path.join(SUBMISSION_DATA_DIR, OUTPUT_FITS_NAME)

    print(f"Requested datetime      : {target_dt}")
    print(f"Chosen file_datetime    : {file_dt}   (from filename)")
    print(f"Chosen upload_time      : {upload_dt} (Last-Modified from listing)")
    print(f"Chosen file             : {filename}")
    print(f"Source                  : {src_gz}")
    print(f"Output                  : {dst_fits}")

    gunzip_to_fits(src_gz, dst_fits)

    print("Done.")


if __name__ == "__main__":
    main()
