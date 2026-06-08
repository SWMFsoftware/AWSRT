import os
import sys
import argparse
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
import matplotlib.dates as mdates
from matplotlib.ticker import MaxNLocator, AutoMinorLocator, LogLocator
from pathlib import Path
from typing import Optional

"""
Plots the simulation results for the last 27 days (approximately a Carrington Rotation)
for the realtime simulation as well as for the daily simulations from 13 and 14 days before
(center of the CR) and compares to real ACE measurements.

Author: Gergely Koban
"""

MAG_HOUR = 6  # magnetogram time hour
BASE_DAILY = Path("/data/Simulations/gergelyk/Daily_SW")


def read_sat_file_realtime(filepath):
    col_names = [
        'it', 'year', 'mo', 'dy', 'hr', 'mn', 'sc', 'msc',
        'X', 'Y', 'Z', 'rho',
        'ux', 'uy', 'uz',
        'bx', 'by', 'bz',
        't', 'I01', 'I02'
    ]

    df = pd.read_csv(filepath, sep=r'\s+', names=col_names, comment='S', skiprows=2)
    df['time'] = pd.to_datetime(df[['year', 'mo', 'dy', 'hr', 'mn', 'sc']].rename(
        columns={'mo': 'month', 'dy': 'day', 'hr': 'hour', 'mn': 'minute', 'sc': 'second'}
    ))
    df = df.set_index('time')

    df['rho_conv'] = df['rho']
    df['V_mag'] = np.sqrt(df['ux']**2 + df['uy']**2 + df['uz']**2)
    df['bx'] *= 1e9
    df['by'] *= 1e9
    df['bz'] *= 1e9
    df['B_mag'] = np.sqrt(df['bx']**2 + df['by']**2 + df['bz']**2) / 10000
    df['temp_calc_K'] = df['t']
    return df


def read_ace_data(filepath):
    col_names = ['Time UT', 'velocity_real', 'density_real', 'temperature_real', 'Bmag_real']
    df = pd.read_csv(filepath, sep=r'\s+', names=col_names, comment="#")
    df['Time UT'] = pd.to_datetime(df['Time UT'])
    df = df.set_index('Time UT')
    return df


def safe_read_sat(reader_func, filepath: Path):
    """Try reading a sat file. Return a DataFrame, or None if missing/unreadable."""
    try:
        if not filepath.exists():
            print(f"[skip] missing: {filepath}")
            return None
        if filepath.stat().st_size == 0:
            print(f"[skip] empty file: {filepath}")
            return None
        return reader_func(str(filepath))
    except Exception as e:
        print(f"[skip] failed reading {filepath}: {e}")
        return None


def read_sat_file(filepath):
    col_names = [
        'it', 'year', 'mo', 'dy', 'hr', 'mn', 'sc', 'msc',
        'X', 'Y', 'Z', 'rho',
        'ux', 'uy', 'uz',
        'bx', 'by', 'bz',
        'p', 'pe', 'ehot',
        't', 'I01', 'I02'
    ]
    df = pd.read_csv(filepath, sep=r'\s+', names=col_names, comment='S', skiprows=2)
    df['time'] = pd.to_datetime(df[['year', 'mo', 'dy', 'hr', 'mn', 'sc']].rename(
        columns={'mo': 'month', 'dy': 'day', 'hr': 'hour', 'mn': 'minute', 'sc': 'second'}
    ))
    df = df.set_index('time')

    df['rho_conv'] = df['rho'] / 1.6726e-27 / 1e3
    df['V_mag'] = np.sqrt(df['ux']**2 + df['uy']**2 + df['uz']**2)
    df['bx'] *= 1e9
    df['by'] *= 1e9
    df['bz'] *= 1e9
    df['B_mag'] = np.sqrt(df['bx']**2 + df['by']**2 + df['bz']**2) / 10000
    df['temp_calc_K'] = df['t']
    return df


def day_start_6am(dt: datetime) -> datetime:
    """Return dt's date at 06:00:00."""
    return dt.replace(hour=MAG_HOUR, minute=0, second=0, microsecond=0)


def parse_target_date(date_string: Optional[str]) -> datetime:
    """
    Parse an optional target date.

    Usage:
      python ensemble_plot_27day.py              # uses today
      python ensemble_plot_27day.py 2026-05-04  # uses 2026-05-04
    """
    if date_string is None:
        return datetime.now()

    for fmt in ("%Y-%m-%d", "%Y%m%d", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(date_string, fmt)
        except ValueError:
            pass

    raise ValueError(
        f"Could not parse date '{date_string}'. Use YYYY-MM-DD, YYYYMMDD, or YYYY-MM-DDTHH:MM:SS."
    )


def daily_folder_for_date(date_obj: datetime) -> Path:
    day_str = date_obj.strftime("%Y-%m-%d")
    return BASE_DAILY / "Website" / "data" / day_str


def load_daily_earth_for_date(date_obj: datetime) -> Optional[pd.DataFrame]:
    folder = daily_folder_for_date(date_obj)
    earth_file = folder / "trj_earth_n00005000.sat"
    return safe_read_sat(read_sat_file, earth_file)


def trim_to_window(df: Optional[pd.DataFrame], t_start: pd.Timestamp, t_end: pd.Timestamp) -> Optional[pd.DataFrame]:
    if df is None or df.empty:
        return None
    out = df.loc[(df.index >= t_start) & (df.index <= t_end)].copy()
    return out if not out.empty else None


def build_27day_segments(target_date: datetime, realtime_path: str, include_daily: bool = True):
    """
    Build model segments for the 27 days before target_date.

    Lines plotted:
      1. Realtime data
      2. Daily simulation initialized 13 days before target_date
      3. Daily simulation initialized 14 days before target_date

    ACE is handled separately in the plotting routine.
    """
    t_end_dt = day_start_6am(target_date)
    t_start_dt = t_end_dt - timedelta(days=27)
    t_start = pd.Timestamp(t_start_dt)
    t_end = pd.Timestamp(t_end_dt)

    segments = {}

    df_rt = safe_read_sat(read_sat_file_realtime, Path(realtime_path))
    df_rt = trim_to_window(df_rt, t_start, t_end)
    if df_rt is not None:
        segments["Realtime"] = df_rt
    else:
        print("[skip] realtime segment empty/missing in requested 27-day window")

    if include_daily:
        for age in (13, 14):
            run_day = t_end_dt - timedelta(days=age)
            df_daily = load_daily_earth_for_date(run_day)
            df_daily = trim_to_window(df_daily, t_start, t_end)
            if df_daily is not None:
                segments[f"Daily D-{age}"] = df_daily
            else:
                print(f"[skip] Daily D-{age} empty/missing in requested 27-day window")
    else:
        print("[info] skipping daily simulation results because --no-daily was used")

    if not segments:
        print("[warning] no model segments available to plot")

    return t_start, t_end, segments


def smooth_ace(df_real_trimmed: pd.DataFrame) -> pd.DataFrame:
    df = df_real_trimmed.copy()
    for col in ['velocity_real', 'density_real', 'temperature_real', 'Bmag_real']:
        if col in df.columns:
            df[col] = df[col].rolling(window=10, center=True, min_periods=1).median()
    return df


def plot_earth_multi(segments: dict, df_real: pd.DataFrame, out_folder: str,
                     t_start: pd.Timestamp, t_end: pd.Timestamp):
    """Plot ACE + realtime + two selected daily simulations over a 27-day window."""

    df_real_trimmed = df_real.loc[(df_real.index >= t_start) & (df_real.index <= t_end)].copy()
    df_real_trimmed = smooth_ace(df_real_trimmed)

    label_fontsize = 14

    plt.rcParams.update({
        "font.size": 12,
        "axes.labelsize": 12,
        "legend.fontsize": 10,
        "axes.titlesize": label_fontsize,
        "xtick.labelsize": label_fontsize,
        "ytick.labelsize": label_fontsize,
    })

    fig, axs = plt.subplots(4, 1, figsize=(10.5, 6.5), sharex=True)
    fig.patch.set_facecolor('#f5f7fa')
    fig.suptitle("Solar Wind parameters at Earth", fontsize=label_fontsize)

    style = {
        "Realtime": dict(color="black", linewidth=1.8, label="Realtime"),
        "Daily D-13": dict(color="tab:orange", linewidth=1.8, label="Daily run D-13"),
        "Daily D-14": dict(color="tab:blue", linewidth=1.8, label="Daily run D-14"),
    }

    ace_col_for_model_col = {
        "V_mag": "velocity_real",
        "rho_conv": "density_real",
        "temp_calc_K": "temperature_real",
        "B_mag": "Bmag_real",
    }

    def plot_segments(ax, ycol, ylabel, logy=False):
        # ACE first, so model lines remain visible on top.
        ace_col = ace_col_for_model_col[ycol]
        if not df_real_trimmed.empty and ace_col in df_real_trimmed.columns:
            ax.plot(
                df_real_trimmed.index.values,
                df_real_trimmed[ace_col].values,
                color="gray",
                linewidth=1.5,
                label="ACE",
            )

        for name, df in segments.items():
            if df is None or df.empty or ycol not in df.columns:
                continue
            kw = style.get(name, dict(linewidth=1.5, label=name))
            ax.plot(df.index.values, df[ycol].values, **kw)

        ax.set_ylabel(ylabel, fontsize=label_fontsize)
        ax.tick_params(labelsize=label_fontsize)
        ax.yaxis.set_major_locator(MaxNLocator(nbins='auto', min_n_ticks=2))
        ax.yaxis.set_minor_locator(AutoMinorLocator())
        ax.tick_params(axis='y', which='major', length=8, width=1.5)
        ax.tick_params(axis='y', which='minor', length=4, width=1)
        if logy:
            ax.set_yscale('log')
            ax.yaxis.set_major_locator(LogLocator(base=10.0, subs=(1.0,), numticks=10))
            ax.yaxis.set_minor_locator(LogLocator(base=10.0, subs='auto', numticks=100))

    plot_segments(axs[0], "V_mag", "V [km/s]")
    plot_segments(axs[1], "rho_conv", "N [1/cm³]")
    plot_segments(axs[2], "temp_calc_K", "T [K]", logy=True)
    plot_segments(axs[3], "B_mag", "B [nT]")

    #window_str = f"Window: {t_start:%Y-%m-%d %H:%M} to {t_end:%Y-%m-%d %H:%M} UTC"
    #axs[3].text(
    #    0.99, 0.02,
    #    window_str,
    #    transform=axs[3].transAxes,
    #    ha="right",
    #    va="bottom",
    #    fontsize=label_fontsize - 4,
    #    alpha=0.7,
    #    color="black",
    #)

    axs[3].xaxis.set_major_locator(mdates.DayLocator(interval=3))
    axs[3].xaxis.set_minor_locator(mdates.DayLocator(interval=1))
    axs[3].xaxis.set_major_formatter(mdates.DateFormatter('%d-%b'))
    axs[3].tick_params(axis='x', which='major', length=8, width=1.5)
    axs[3].tick_params(axis='x', which='minor', length=4, width=1)

    for ax in axs:
        ax.set_xlim(t_start, t_end)

    handles, labels = axs[0].get_legend_handles_labels()
    # Preserve order and avoid duplicate labels.
    unique = dict(zip(labels, handles))
    fig.legend(
        unique.values(),
        unique.keys(),
        loc='lower center',
        bbox_to_anchor=(0.5, 0.01),
        ncol=4,
        prop={'size': 9},
        markerscale=0.7,
    )

    plt.tight_layout(rect=[0, 0.08, 1, 0.96])
    os.makedirs(out_folder, exist_ok=True)
    outpath = os.path.join(out_folder, "Earth_27day.png")
    plt.savefig(outpath, dpi=300)
    plt.close(fig)
    print(f"[done] wrote {outpath}")


def main():
    parser = argparse.ArgumentParser(
        description="Plot ACE, realtime, and selected daily Earth solar-wind simulations over the 27 days before a target date."
    )
    parser.add_argument(
        "date",
        nargs="?",
        help="Target/end date. Use YYYY-MM-DD. If omitted, today is used.",
    )
    parser.add_argument(
        "--no-daily",
        action="store_true",
        help="Omit daily simulation results and plot only ACE plus realtime results.",
    )
    args = parser.parse_args()

    target_date = parse_target_date(args.date)

    out_folder = "/data/Simulations/gergelyk/Daily_SW/AWSRT/Realtime_BG_results/"
    ace_file = "/data/Simulations/gergelyk/Daily_SW/27days_SW.txt"
    realtime_file = "/data/Simulations/gergelyk/Daily_SW/AWSRT/Realtime_BG_results/sat_earth_realtime.sat"

    df_ace = read_ace_data(ace_file)
    t_start, t_end, segments = build_27day_segments(
        target_date,
        realtime_file,
        include_daily=not args.no_daily,
    )
    plot_earth_multi(segments, df_ace, out_folder=out_folder, t_start=t_start, t_end=t_end)


if __name__ == "__main__":
    main()
