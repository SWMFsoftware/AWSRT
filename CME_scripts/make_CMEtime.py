#!/usr/bin/env python3
"""
Create CMETIME.in from CME.json.

Example CME.json:
[{"id": "2026-01-18T18:09:00-CME-001", "speed": 1431.0, "location": "S15E20"}]

Writes:
<run_dir>/SC/CMETIME.in
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any


def parse_cme_time_from_id(cme_id: str) -> datetime:
    """
    Extract datetime from an id like:
      '2026-01-18T18:09:00-CME-001'
    We take the part before '-CME-'.
    """
    if "-CME-" not in cme_id:
        raise ValueError(f"Unexpected id format (missing '-CME-'): {cme_id!r}")
    dt_str = cme_id.split("-CME-", 1)[0].strip()

    # Expect ISO-like "YYYY-MM-DDTHH:MM:SS"
    try:
        return datetime.strptime(dt_str, "%Y-%m-%dT%H:%M:%S")
    except ValueError as e:
        raise ValueError(f"Could not parse datetime from id prefix {dt_str!r}") from e


def write_cmetime_in(dt: datetime, out_path: Path) -> None:
    """
    Write CMETIME.in with the exact spacing/alignment shown in the prompt.
    """
    lines = [
        f"{dt.year:>8}                iYear\n",
        f"{dt.month:>8}                iMonth\n",
        f"{dt.day:>8}                iDay\n",
        f"{dt.hour:>8}                iHour\n",
        f"{dt.minute:>8}                iMinute\n",
        f"{dt.second:>8}                iSecond\n",
        f"{0.0:<24}FracSecond\n",
        "#END\n",
    ]
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("".join(lines))


def load_cme_json(path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text())
    if not isinstance(data, list) or not data:
        raise ValueError(f"{path} must contain a non-empty JSON list.")
    if not isinstance(data[0], dict):
        raise ValueError(f"{path} first element must be an object/dict.")
    return data  # type: ignore[return-value]


def main() -> int:
    p = argparse.ArgumentParser(description="Generate SC/CMETIME.in from CME.json")
    p.add_argument(
        "--cme-json",
        default="/nobackupp28/gkoban/Realtime/SWMF/SUBMISSION_DATA/CME.json",
        help="Path to CME.json (default: %(default)s)",
    )
    p.add_argument(
        "--run-dir",
        default="/nobackupp28/gkoban/Realtime/SWMF/run_realtime_Event1",
        help="Run directory containing SC/ (default: %(default)s)",
    )
    p.add_argument(
        "--index",
        type=int,
        default=0,
        help="Which CME entry to use from the list (default: 0)",
    )
    args = p.parse_args()

    cme_json_path = Path(args.cme_json)
    run_dir = Path(args.run_dir)

    cmes = load_cme_json(cme_json_path)
    if not (0 <= args.index < len(cmes)):
        raise SystemExit(f"--index {args.index} out of range (0..{len(cmes)-1}).")

    cme_id = cmes[args.index].get("id")
    if not isinstance(cme_id, str) or not cme_id.strip():
        raise ValueError(f"Missing/invalid 'id' field at index {args.index} in {cme_json_path}")

    dt = parse_cme_time_from_id(cme_id)
    out_path = run_dir / "SC" / "CMETIME.in"
    write_cmetime_in(dt, out_path)

    print(f"Wrote {out_path} from CME id {cme_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
