#!/usr/bin/env python3
"""
Generate CME_AMR.in and IHCME_AMR.in from CME.in (#CME block only).

Usage:
  python make_CMEin.py
  python make_CMEin.py --infile /path/to/CME.in --outdir /path/to/output
"""

from __future__ import annotations
import argparse
import os
import re
from typing import Dict, Tuple


def _parse_cme_block(filepath: str) -> Dict[str, float]:
    """
    Parse the #CME ... #END block and return needed parameters.

    Expected lines in the block look like:
      212.50              LongitudeCme
      17.84               LatitudeCme
      0.20                Radius

    This parser is tolerant to extra whitespace and trailing comments.
    """
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    in_cme = False
    params: Dict[str, float] = {}

    # Match: number then a name token
    # Supports floats like -1, -1.0, 1.23, 1.2e-3, etc.
    value_name_re = re.compile(
        r"^\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s+([A-Za-z_]\w*)\s*(?:#.*)?$"
    )

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("#CME"):
            in_cme = True
            continue

        if in_cme and stripped.startswith("#END"):
            break

        if not in_cme:
            continue

        m = value_name_re.match(line)
        if not m:
            continue

        val = float(m.group(1))
        name = m.group(2)
        params[name] = val

    # Required keys
    required = ["LongitudeCme", "LatitudeCme", "Radius"]
    missing = [k for k in required if k not in params]
    if missing:
        raise ValueError(
            f"Missing required CME keys in #CME block: {missing}. "
            f"Found keys: {sorted(params.keys())}"
        )

    return params


def _wrap_longitude_deg(lon: float) -> float:
    """Wrap longitude to [0, 360)."""
    return lon % 360.0


def _compute_amr_bounds(lon: float, lat: float, radius: float,
                        lon_mult: float = 40.0, lat_mult: float = 20.0) -> Tuple[float, float, float, float]:
    """
    Compute:
      LongMin = lon - lon_mult * radius
      LongMax = lon + lon_mult * radius
      LatMin  = lat - lat_mult * radius
      LatMax  = lat + lat_mult * radius

    NOTE:
      - Longitudes are wrapped into [0, 360) individually.
      - Latitudes are NOT clamped here; if you want clamp to [-90, 90], add it.
    """
    long_min = _wrap_longitude_deg(lon - lon_mult * radius)
    long_max = _wrap_longitude_deg(lon + lon_mult * radius)
    lat_min = lat - lat_mult * radius
    lat_max = lat + lat_mult * radius
    return long_min, lat_min, long_max, lat_max


def write_cme_amr(outpath: str, long_min: float, lat_min: float, long_max: float, lat_max: float) -> None:
    """
    Write CME_AMR.in
    Hardwired: 1.1 and 22
    """
    content = (
        "#AMRREGION\n"
        "CMEbox\n"
        "box_gen\n"
        "1.1\n"
        f"{long_min:.1f}         LongMin\n"
        f"{lat_min:.1f}          LatMin\n"
        "22\n"
        f"{long_max:.1f}         LongMax\n"
        f"{lat_max:.1f}          LatMax\n"
        "\n"
        "#END\n"
    )
    with open(outpath, "w", encoding="utf-8") as f:
        f.write(content)


def write_ihcme_amr(outpath: str, lon: float, lat: float) -> None:
    """
    Write IHCME_AMR.in with:
      yrotate = -LatitudeCme
      zrotate =  LongitudeCme
    Hardwired: Height=220.0, Radius=127.0 (cone)
    """
    yrotate = -lat
    zrotate = lon
    content = (
        "#AMRREGION\n"
        "coneIH_CME              NameRegion\n"
        "conex rotated           StringShape\n"
        "0.0                     xPosition\n"
        "0.0                     yPosition\n"
        "0.0                     zPosition\n"
        "220.0                   Height\n"
        "127.0                   Radius\n"
        "0.0                     xrotate\n"
        f"{yrotate: .1f}                  yrotate\n"
        f"{zrotate: .1f}                  zrotate\n"
        "\n"
        "#END\n"
    )
    with open(outpath, "w", encoding="utf-8") as f:
        f.write(content)


def main() -> None:
    ap = argparse.ArgumentParser(description="Generate CME_AMR.in and IHCME_AMR.in from CME.in")
    ap.add_argument("--infile", default="CME.in", help="Path to CME.in (default: ./CME.in)")
    ap.add_argument("--outdir", default=".", help="Output directory (default: current directory)")
    ap.add_argument("--lon-mult", type=float, default=40.0, help="Longitude multiplier for Radius (default: 40)")
    ap.add_argument("--lat-mult", type=float, default=20.0, help="Latitude multiplier for Radius (default: 20)")
    args = ap.parse_args()

    params = _parse_cme_block(args.infile)
    lon = float(params["LongitudeCme"])
    lat = float(params["LatitudeCme"])
    radius = float(params["Radius"])

    long_min, lat_min, long_max, lat_max = _compute_amr_bounds(
        lon=lon, lat=lat, radius=radius,
        lon_mult=args.lon_mult, lat_mult=args.lat_mult
    )

    os.makedirs(args.outdir, exist_ok=True)

    cme_amr_path = os.path.join(args.outdir, "CME_AMR.in")
    ihcme_amr_path = os.path.join(args.outdir, "IHCME_AMR.in")

    write_cme_amr(cme_amr_path, long_min, lat_min, long_max, lat_max)
    write_ihcme_amr(ihcme_amr_path, lon, lat)

    print(f"Wrote: {cme_amr_path}")
    print(f"Wrote: {ihcme_amr_path}")
    print(f"Inputs used: LongitudeCme={lon}, LatitudeCme={lat}, Radius={radius}")
    print(f"Computed bounds (lon_mult={args.lon_mult}, lat_mult={args.lat_mult}): "
          f"LongMin={long_min:.1f}, LongMax={long_max:.1f}, LatMin={lat_min:.1f}, LatMax={lat_max:.1f}")


if __name__ == "__main__":
    main()

