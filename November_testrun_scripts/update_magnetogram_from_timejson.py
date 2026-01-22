#!/usr/bin/env python3
"""
Wrapper to call get_magnetogram_offline.py using current_time from time.json.
"""

import json
import subprocess
import datetime
from pathlib import Path
import sys


TIME_JSON = Path("/nobackupp28/gkoban/Realtime/SWMF/SUBMISSION_DATA/time.json")
MAG_SCRIPT = Path("/nobackupp28/gkoban/Realtime/SWMF/get_magnetogram_offline.py")


def read_current_time(path: Path) -> datetime.datetime:
    with path.open("r") as f:
        data = json.load(f)

    if "current_time" not in data:
        raise KeyError(f"'current_time' not found in {path}")

    ct = datetime.datetime.fromisoformat(data["current_time"])

    # If timezone-aware → convert to naive UTC (safe for your pipeline)
    if ct.tzinfo is not None:
        ct = ct.astimezone(datetime.timezone.utc).replace(tzinfo=None)

    return ct


def main():
    if not TIME_JSON.exists():
        sys.exit(f"ERROR: {TIME_JSON} does not exist")

    if not MAG_SCRIPT.exists():
        sys.exit(f"ERROR: {MAG_SCRIPT} does not exist")

    current_time = read_current_time(TIME_JSON)

    # Format exactly as required: "YYYY-MM-DD HH:MM"
    time_arg = current_time.strftime("%Y-%m-%d %H:%M")

    cmd = [
        sys.executable,              # ensures same python env
        str(MAG_SCRIPT),
        time_arg
    ]

    print("Calling:", " ".join(cmd))
    subprocess.run(cmd, check=True)


if __name__ == "__main__":
    main()
