#!/usr/bin/env python3
"""
Create STOPTIME.in in <run_dir>/SC using the time difference between:
  - CMETIME.in
  - ENDMAGNETOGRAMTIME.in

STOPTIME.in format:
#STOP
-1                     MaxIter
<N> m                  TimeMax
#END
"""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path


FIELDS = ("iYear", "iMonth", "iDay", "iHour", "iMinute", "iSecond")


def parse_time_file(path: Path) -> datetime:
    """
    Parse files formatted like:
        2026                iYear
           2                iMonth
           ...
    Ignores FracSecond and comments.
    """
    values: dict[str, int] = {}

    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue

        # Stop at "#END" (already handled by startswith("#"), but keep safe)
        if line.upper() == "END":
            break

        parts = line.split()
        if len(parts) < 2:
            continue

        val_str, key = parts[0], parts[1]
        if key in FIELDS:
            try:
                values[key] = int(val_str)
            except ValueError as e:
                raise ValueError(f"Failed parsing integer for {key} in {path}: {val_str}") from e

    missing = [k for k in FIELDS if k not in values]
    if missing:
        raise ValueError(f"Missing fields {missing} in {path}")

    return datetime(
        year=values["iYear"],
        month=values["iMonth"],
        day=values["iDay"],
        hour=values["iHour"],
        minute=values["iMinute"],
        second=values["iSecond"],
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate STOPTIME.in from CMETIME.in and ENDMAGNETOGRAMTIME.in")
    ap.add_argument("run_dir", help="Run directory that contains SC/CMETIME.in and SC/ENDMAGNETOGRAMTIME.in")
    args = ap.parse_args()

    run_dir = Path(args.run_dir).expanduser().resolve()
    sc_dir = run_dir / "SC"

    cme_file = sc_dir / "CMETIME.in"
    endmag_file = sc_dir / "ENDMAGNETOGRAMTIME.in"
    out_file = sc_dir / "STOPTIME.in"

    if not sc_dir.is_dir():
        raise SystemExit(f"Error: SC directory not found: {sc_dir}")
    if not cme_file.is_file():
        raise SystemExit(f"Error: missing file: {cme_file}")
    if not endmag_file.is_file():
        raise SystemExit(f"Error: missing file: {endmag_file}")

    cme_dt = parse_time_file(cme_file)
    endmag_dt = parse_time_file(endmag_file)

    # ENDMAGNETOGRAMTIME.in is earlier; still compute robustly:
    delta_seconds = (cme_dt - endmag_dt).total_seconds()
    if delta_seconds < 0:
        raise SystemExit(
            f"Error: CMETIME ({cme_dt}) is earlier than ENDMAGNETOGRAMTIME ({endmag_dt})."
        )

    minutes = int(round(delta_seconds / 60.0))
    # If you prefer truncation instead of rounding, use:
    # minutes = int(delta_seconds // 60)

    out_text = (
        "#STOP\n"
        "-1                     MaxIter\n"
        f"{minutes} m                  TimeMax\n"
        "#END\n"
    )

    out_file.write_text(out_text)
    print(f"Wrote {out_file} (TimeMax = {minutes} m)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
