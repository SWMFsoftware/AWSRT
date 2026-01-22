#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from datetime import datetime
from pathlib import Path
from typing import Dict


KEYS = {
    "iYear": "year",
    "iMonth": "month",
    "iDay": "day",
    "iHour": "hour",
    "iMinute": "minute",
    "iSecond": "second",
}


def parse_time_in(path: Path) -> datetime:
    """
    Parse files like:
        2025                iYear
          11                iMonth
           9                iDay
           7                iHour
          14                iMinute
           0                iSecond
    """
    if not path.exists():
        raise FileNotFoundError(f"Missing file: {path}")

    vals: Dict[str, int] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.upper() == "#END":
            continue

        # match: <number><spaces><key>
        m = re.match(r"^([+-]?\d+)\s+([A-Za-z]\w+)\s*$", line)
        if not m:
            continue

        num_s, key = m.group(1), m.group(2)
        if key in KEYS:
            vals[KEYS[key]] = int(num_s)

    missing = [v for v in ("year", "month", "day", "hour", "minute", "second") if v not in vals]
    if missing:
        raise ValueError(f"{path} is missing fields: {missing}")

    return datetime(
        year=vals["year"],
        month=vals["month"],
        day=vals["day"],
        hour=vals["hour"],
        minute=vals["minute"],
        second=vals["second"],
    )


def format_minutes_compact(x: float) -> str:
    """
    Format minutes for 'DtAmr' as '<value> m'
    - If essentially an integer -> '17 m'
    - Else -> up to 2 decimals, trimmed: '17.5 m', '17.33 m'
    """
    # guard tiny negative due to float noise
    if x < 0 and x > -1e-12:
        x = 0.0

    # integer if close
    xi = round(x)
    if abs(x - xi) < 1e-9:
        return f"{int(xi)} m"

    s = f"{x:.2f}".rstrip("0").rstrip(".")
    return f"{s} m"


def write_amr_settings(path: Path, dt_amr_minutes: float) -> None:
    dt_str = format_minutes_compact(dt_amr_minutes)

    content = (
        "#DOAMR\n"
        "T\t\t\tDoAmr\n"
        "-1\t\t\tDnAmr\n"
        f"{dt_str}\t\t\tDtAmr\n"
        "T\t\t\tIsStrictAmr\n"
    )

    path.write_text(content)


def main() -> int:
    p = argparse.ArgumentParser(description="Create AMR_settings.in from ENDMAGNETOGRAMTIME.in and CMETIME.in")
    p.add_argument(
        "--run-dir",
        default="/nobackupp28/gkoban/Realtime/SWMF/run_realtime_Event1",
        help="Run directory containing SC/ (default: %(default)s)",
    )
    p.add_argument(
        "--n-amr",
        type=int,
        default=3,
        help="Number of AMR steps between endmag and CME (default: 3)",
    )
    p.add_argument(
        "--min-dt-minutes",
        type=float,
        default=1.0,
        help="Minimum allowed DtAmr in minutes (default: 1.0)",
    )
    args = p.parse_args()

    run_dir = Path(args.run_dir)
    sc_dir = run_dir / "SC"

    endmag_path = sc_dir / "ENDMAGNETOGRAMTIME.in"
    cme_path = sc_dir / "CMETIME.in"
    out_path = sc_dir / "AMR_settings.in"

    t0 = parse_time_in(endmag_path)
    t1 = parse_time_in(cme_path)

    if t1 <= t0:
        raise ValueError(
            f"CMETIME ({t1.isoformat(sep=' ')}) must be after ENDMAGNETOGRAMTIME ({t0.isoformat(sep=' ')})"
        )

    total_minutes = (t1 - t0).total_seconds() / 60.0
    dt_amr = total_minutes / float(args.n_amr)

    # safety clamp to avoid zero/too-small intervals
    if dt_amr < args.min_dt_minutes:
        dt_amr = args.min_dt_minutes

    sc_dir.mkdir(parents=True, exist_ok=True)
    write_amr_settings(out_path, dt_amr)

    print(f"Wrote {out_path}")
    print(f"ENDMAGNETOGRAMTIME: {t0.isoformat(sep=' ')}")
    print(f"CMETIME:            {t1.isoformat(sep=' ')}")
    print(f"Total minutes: {total_minutes:.3f}, DtAmr: {format_minutes_compact(dt_amr)} (n={args.n_amr})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

