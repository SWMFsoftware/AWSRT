#!/usr/bin/env python3
import argparse
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Tuple


CYCLE_RE = re.compile(r"^cycle_(\d{6})_(\d{6})$")


def parse_cme_time_from_processed_json(processed_json: Path) -> datetime:
    """
    processed_CME.json example:
      [{"id": "2025-11-09T07:24:00-CME-001", "speed": 734.0, "location": "N27E03"}]
    We parse the datetime prefix up to seconds: YYYY-MM-DDTHH:MM:SS
    """
    data = json.loads(processed_json.read_text())

    if not isinstance(data, list) or len(data) == 0 or "id" not in data[0]:
        raise ValueError(f"Unexpected JSON format in {processed_json}")

    cme_id = data[0]["id"]
    # Take the first 19 chars: "YYYY-MM-DDTHH:MM:SS"
    # This is robust even if "-CME-001" changes.
    dt_str = str(cme_id)[:19]
    try:
        return datetime.strptime(dt_str, "%Y-%m-%dT%H:%M:%S")
    except ValueError as e:
        raise ValueError(f"Could not parse CME time from id={cme_id!r} in {processed_json}") from e


def parse_endmagnetogramtime(path: Path) -> datetime:
    """
    parse ENDMAGNETOGRAMTIME.in
    """
    lines = path.read_text().splitlines()

    def first_number(line: str) -> str:
        return line.strip().split()[0]

    # Basic safety: expect at least 7 numeric lines
    if len(lines) < 7:
        raise ValueError(f"Too few lines in {path}")

    year = int(first_number(lines[0]))
    month = int(first_number(lines[1]))
    day = int(first_number(lines[2]))
    hour = int(first_number(lines[3]))
    minute = int(first_number(lines[4]))
    second = int(first_number(lines[5]))

    # Fractional seconds might be float; optional
    frac = 0.0
    try:
        frac = float(first_number(lines[6]))
    except Exception:
        frac = 0.0

    dt = datetime(year, month, day, hour, minute, second)
    if frac and frac > 0:
        dt = dt + timedelta(seconds=frac)
    return dt


def cycle_name_to_dt(cycle_dir: Path) -> Optional[datetime]:
    """
    cycle_251109_141312 -> 2025-11-09 14:13:12 (assumes 2000+YY)
    Returns None if name doesn't match expected pattern.
    """
    m = CYCLE_RE.match(cycle_dir.name)
    if not m:
        return None
    yymmdd, hhmmss = m.group(1), m.group(2)
    yy = int(yymmdd[0:2])
    mm = int(yymmdd[2:4])
    dd = int(yymmdd[4:6])
    hh = int(hhmmss[0:2])
    mi = int(hhmmss[2:4])
    ss = int(hhmmss[4:6])
    return datetime(2000 + yy, mm, dd, hh, mi, ss)


@dataclass(frozen=True)
class CycleInfo:
    cycle_dir: Path
    cycle_dt: datetime
    endmag_dt: datetime


def find_best_cycle(run_realtime: Path, cme_root: Path) -> Tuple[CycleInfo, datetime]:
    processed = cme_root / "processed_CME.json"
    if not processed.is_file():
        raise FileNotFoundError(f"Missing {processed}")

    cme_time = parse_cme_time_from_processed_json(processed)

    checkpoints_dir = run_realtime / "checkpoints"
    if not checkpoints_dir.is_dir():
        raise FileNotFoundError(f"Missing checkpoints dir: {checkpoints_dir}")

    cycles: list[CycleInfo] = []
    for d in checkpoints_dir.iterdir():
        if not d.is_dir():
            continue
        cdt = cycle_name_to_dt(d)
        if cdt is None:
            continue

        endmag = d / "SC_cleanup" / "ENDMAGNETOGRAMTIME.in"
        if not endmag.is_file():
            continue

        try:
            endmag_dt = parse_endmagnetogramtime(endmag)
        except Exception:
            # Skip malformed files
            continue

        cycles.append(CycleInfo(cycle_dir=d, cycle_dt=cdt, endmag_dt=endmag_dt))

    if not cycles:
        raise RuntimeError(f"No usable cycles found in {checkpoints_dir}")

    # Newest -> oldest by cycle folder timestamp
    cycles.sort(key=lambda x: x.cycle_dt, reverse=True)

    # Find the first (newest) cycle whose ENDMAGNETOGRAMTIME is strictly before CME time
    for ci in cycles:
        if ci.endmag_dt < cme_time:
            return ci, cme_time

    raise RuntimeError(
        f"No cycle found with ENDMAGNETOGRAMTIME before CME time {cme_time.isoformat()} "
        f"(checked {len(cycles)} cycles)."
    )


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Select latest checkpoint cycle whose ENDMAGNETOGRAMTIME is before CME time."
    )
    ap.add_argument(
        "--run-realtime",
        required=True,
        help="Path to run_realtime directory (must contain checkpoints/).",
    )
    ap.add_argument(
        "--cme-root",
        required=True,
        help="Path to CME root folder containing processed_CME.json.",
    )
    ap.add_argument(
        "--print",
        choices=["cycle_dir", "endmag_dt", "cme_dt", "all"],
        default="cycle_dir",
        help="What to print to stdout (default: cycle_dir).",
    )
    args = ap.parse_args()

    run_realtime = Path(args.run_realtime).expanduser().resolve()
    cme_root = Path(args.cme_root).expanduser().resolve()

    ci, cme_time = find_best_cycle(run_realtime, cme_root)

    if args.print == "cycle_dir":
        print(str(ci.cycle_dir))
    elif args.print == "endmag_dt":
        print(ci.endmag_dt.isoformat(sep=" "))
    elif args.print == "cme_dt":
        print(cme_time.isoformat(sep=" "))
    else:
        print(f"cycle_dir={ci.cycle_dir}")
        print(f"cycle_name_dt={ci.cycle_dt.isoformat(sep=' ')}")
        print(f"endmag_dt={ci.endmag_dt.isoformat(sep=' ')}")
        print(f"cme_dt={cme_time.isoformat(sep=' ')}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        raise SystemExit(2)

