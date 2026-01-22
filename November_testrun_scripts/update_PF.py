#!/usr/bin/env python3
"""
Update PoyntingFluxPerBSi in CORONALHEATING.in based on current_time in time.json.
"""

import json
import datetime
import re
from pathlib import Path


# -------------------- PF logic --------------------

def get_difference_days(date1, date2):
    delta = date2 - date1
    return int(delta.days)

def Calc_PoyntingFlux(date):
    # change if Poynting Flux per day:
    Pchange = 391

    # Min and Max values for Poynting Flux
    PFmin = 300000
    PFmax = 1100000

    # dates for solar minima and maxima - To be expanded for further use
    SC23D2 = datetime.datetime(2001, 11, 13)

    SC24D1 = datetime.datetime(2008, 12, 17)
    SC24D2 = datetime.datetime(2014, 11, 11)

    SC25D1 = datetime.datetime(2019, 12, 10)
    SC25D2 = datetime.datetime(2025, 7, 17)

    SC26D1 = datetime.datetime(2030, 12, 20)

    if SC24D1 < date < SC24D2:
        days = int(get_difference_days(SC24D1, date))
        return PFmax - days * 371
    elif SC25D1 < date < SC25D2:
        days = int(get_difference_days(SC25D1, date))
        return PFmax - days * Pchange
    elif SC24D2 < date < SC25D1:
        days = int(get_difference_days(SC24D2, date))
        return PFmin + days * 431
    elif SC23D2 < date < SC24D1:
        days = int(get_difference_days(SC23D2, date))
        return PFmin + days * 308
    elif SC25D2 < date < SC26D1:
        days = int(get_difference_days(SC25D2, date))
        return PFmin + days * 403
    else:
        raise ValueError(
            f"Date {date.isoformat()} not included for Poynting Flux calculation yet."
        )

def format_scientific_clean(value: float) -> str:
    s = "{:.5e}".format(value)
    base, exponent = s.split("e")
    exponent = int(exponent)  # "+05" -> 5
    return f"{base}e{exponent}"


# -------------------- File ops --------------------

def read_current_time(time_json_path: Path) -> datetime.datetime:
    with time_json_path.open("r") as f:
        data = json.load(f)

    if "current_time" not in data:
        raise KeyError(f"Missing 'current_time' in {time_json_path}")

    # Handles "YYYY-MM-DDTHH:MM:SS" and also timezone-aware strings if present
    ct = datetime.datetime.fromisoformat(data["current_time"])
    # If timezone-aware, convert to naive UTC for your Calc_PoyntingFlux comparisons
    if ct.tzinfo is not None:
        ct = ct.astimezone(datetime.timezone.utc).replace(tzinfo=None)
    return ct

def update_coronalheating_poyntingflux(ch_path: Path, new_pf_str: str) -> None:
    """
    Replace the numeric value on the PoyntingFluxPerBSi line, preserving spacing + comment.
    Example line:
      0.5e6                   PoyntingFluxPerBSi [J/m^2/s/T]
    """
    text = ch_path.read_text()

    # Match a full line that contains "... PoyntingFluxPerBSi [J/m^2/s/T]"
    # Capture leading whitespace and everything after the value so we preserve formatting.
    pattern = re.compile(
        r'^(?P<indent>\s*)'
        r'(?P<value>[-+]?(\d+(\.\d*)?|\.\d+)([eE][-+]?\d+)?)'
        r'(?P<rest>\s+PoyntingFluxPerBSi\s*\[J/m\^2/s/T\]\s*)$',
        re.MULTILINE
    )

    m = pattern.search(text)
    if not m:
        raise RuntimeError(
            f"Could not find a line with 'PoyntingFluxPerBSi [J/m^2/s/T]' in {ch_path}"
        )

    new_line = f"{m.group('indent')}{new_pf_str}{m.group('rest')}"
    new_text = pattern.sub(new_line, text, count=1)

    ch_path.write_text(new_text)

def main():
    # Adjust these paths as needed
    time_json_path = Path("/nobackupp28/gkoban/Realtime/SWMF/SUBMISSION_DATA/time.json")
    coronalheating_path = Path("/nobackupp28/gkoban/Realtime/SWMF/run_realtime/SC/CORONALHEATING.in")

    current_time = read_current_time(time_json_path)
    pf_value = Calc_PoyntingFlux(current_time)
    pf_formatted = format_scientific_clean(pf_value)

    update_coronalheating_poyntingflux(coronalheating_path, pf_formatted)

    print(f"current_time = {current_time.isoformat()}")
    print(f"PF value     = {pf_value}")
    print(f"PF written   = {pf_formatted}")
    print(f"Updated      = {coronalheating_path}")

if __name__ == "__main__":
    main()

