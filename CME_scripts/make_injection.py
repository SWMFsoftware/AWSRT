#!/usr/bin/env python3

import argparse
import json
import math
from pathlib import Path

"""
Changes the EfficiencyInj variable based on CME speed.
Creates the INJECTION.in file, read by the PARAM.in.

Author: Gergely Koban
"""

# Easy-to-change reference speed in km/s
REFERENCE_SPEED = 1500.0


def read_cme_speed(json_path: Path) -> float:
    """Read the CME speed from the first entry in the JSON file."""
    try:
        with json_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        raise FileNotFoundError(f"JSON file not found: {json_path}")
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {json_path}: {e}")

    if not isinstance(data, list) or len(data) == 0:
        raise ValueError("JSON file must contain a non-empty list.")

    first_entry = data[0]
    if not isinstance(first_entry, dict):
        raise ValueError("First JSON entry must be an object/dictionary.")

    if "speed" not in first_entry:
        raise ValueError("JSON entry does not contain a 'speed' field.")

    try:
        speed = float(first_entry["speed"])
    except (TypeError, ValueError):
        raise ValueError(f"Invalid speed value: {first_entry['speed']}")

    return speed


def calculate_injection_efficiency(v_cme: float, reference_speed: float) -> float:
    """Compute injection efficiency using:
       inj = exp((v_CME - reference_speed) / reference_speed)
    """
    return math.exp((v_cme - reference_speed) / reference_speed)


def write_injection_file(sc_dir: Path, inj_value: float) -> Path:
    """Write the INJECTION.IN file into the SC directory."""
    output_path = sc_dir / "INJECTION.IN"

    content = (
        "inject                                  TypeMomentumMinBc\n"
        "5                                     SpectralIndex\n"
        f"{inj_value:.3f}                               EfficiencyInj\n"
        "escape                                  TypeMomentumMaxBc\n"
    )

    with output_path.open("w", encoding="utf-8") as f:
        f.write(content)

    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate INJECTION.IN from CME JSON input."
    )
    parser.add_argument(
        "json_file",
        type=Path,
        help="Path to the JSON file containing CME data."
    )
    parser.add_argument(
        "run_directory",
        type=Path,
        help="Path to the run directory. INJECTION.IN will be written to run_directory/SC/"
    )

    args = parser.parse_args()

    sc_dir = args.run_directory / "SC"
    if not sc_dir.is_dir():
        raise FileNotFoundError(f"SC directory not found: {sc_dir}")

    v_cme = read_cme_speed(args.json_file)
    inj = calculate_injection_efficiency(v_cme, REFERENCE_SPEED)
    output_file = write_injection_file(sc_dir, inj)

    print(f"Read CME speed: {v_cme}")
    print(f"Calculated injection efficiency: {inj:.6f}")
    print(f"Wrote file: {output_file}")


if __name__ == "__main__":
    main()
