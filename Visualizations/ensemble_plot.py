import os
import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
import matplotlib.dates as mdates
from matplotlib.ticker import MaxNLocator, AutoMinorLocator, LogLocator
from matplotlib.dates import ConciseDateFormatter
from pathlib import Path
from typing import Optional

"""
Creates an ensemble plot from the realtime results, the last three days' daily 
simulations results and the real ACE data. It can handle data gaps or missing
results, so it can be run by cron.

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

    df['rho_conv'] = df['rho'] #/ 1.6726e-27 / 1e3
    df['V_mag'] = np.sqrt(df['ux']**2 + df['uy']**2 + df['uz']**2)
    df['bx'] *= 1e9
    df['by'] *= 1e9
    df['bz'] *= 1e9
    df['B_mag'] = np.sqrt(df['bx']**2 + df['by']**2 + df['bz']**2) / 10000

    m_p = 1.6726e-27
    e = 1.602e-19
    k_B = 1.380649e-23  # Boltzmann constant in J/K
    #df['temp_calc_eV'] = df['p'] * m_p / (df['rho'] * e) / 1000
    #df['temp_calc_K'] = df['P'] * m_p / (df['rho'] * k_B) / 1000
    df['temp_calc_K'] = df['t']
    return df

def read_ace_data(filepath):
    # Define expected column names
    col_names = ['Time UT', 'velocity_real', 'density_real', 'temperature_real', 'Bmag_real']

    # Read file directly without skipping any rows or parsing metadata
    df = pd.read_csv(filepath, sep=r'\s+', names=col_names, comment="#")
    df['Time UT'] = pd.to_datetime(df['Time UT'])
    df = df.set_index('Time UT')
    return df

def get_folder_path():
    """Return the folder path to use: today's date or command-line provided."""
    if len(sys.argv) > 1:
        return sys.argv[1]
    else:
        today_str = datetime.now().strftime('%Y-%m-%d')
        return os.path.join("Website", "data", today_str)

def safe_read_sat(reader_func, filepath: Path):
    """
    Try reading a sat file. Return a DataFrame, or None if missing/unreadable.
    """
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
        't','I01', 'I02'
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

    m_p = 1.6726e-27
    e = 1.602e-19
    k_B = 1.380649e-23  # Boltzmann constant in J/K
    #df['temp_calc_eV'] = df['p'] * m_p / (df['rho'] * e) / 1000
    #df['temp_calc_K'] = df['p'] * m_p / (df['rho'] * k_B) / 1000
    df['temp_calc_K'] = df['t']
    return df

def day_start_6am(dt: datetime) -> datetime:
    """Return dt's date at 06:00:00."""
    return dt.replace(hour=MAG_HOUR, minute=0, second=0, microsecond=0)

def slice_shift_horizon(df: pd.DataFrame, t0_run: pd.Timestamp, t0_today: pd.Timestamp, horizon_days: int) -> pd.DataFrame:
    """
    1) slice 4-day chunk starting at t0_run
    2) shift it so t0_run maps to t0_today
    3) clip to [t0_today, t0_today + horizon_days]
    """
    t0_run = pd.Timestamp(t0_run)
    t0_today = pd.Timestamp(t0_today)

    # 4-day chunk in run-time coordinates
    df4 = df.loc[(df.index >= t0_run) & (df.index < t0_run + pd.Timedelta(days=4))].copy()
    if df4.empty:
        return df4

    # shift to today axis
    shift = t0_today - t0_run
    df4.index = df4.index + shift

    # horizon clip (today:4d, yesterday:3d, ...)
    df4 = df4.loc[(df4.index >= t0_today) & (df4.index < t0_today + pd.Timedelta(days=horizon_days))].copy()
    return df4

def daily_folder_for_date(date_obj: datetime) -> Path:
    day_str = date_obj.strftime("%Y-%m-%d")
    return BASE_DAILY / "Website" / "data" / day_str

def load_daily_earth_for_date(date_obj: datetime) -> Optional[pd.DataFrame]:
    folder = daily_folder_for_date(date_obj)        # Path
    earth_file = folder / "trj_earth_n00005000.sat" # Path
    return safe_read_sat(read_sat_file, earth_file)

def load_realtime_earth(realtime_path: str) -> pd.DataFrame:
    return read_sat_file_realtime(realtime_path)

def build_segments(now: datetime, realtime_path: str):
    t0_today_dt = day_start_6am(now)
    t0_today = pd.Timestamp(t0_today_dt)

    segments = {}

    # realtime (optional too)
    df_rt = safe_read_sat(read_sat_file_realtime, Path(realtime_path))
    if df_rt is not None:
        df_rt = df_rt.loc[df_rt.index >= t0_today].copy()
        df_rt = df_rt.loc[df_rt.index < t0_today + pd.Timedelta(days=4)]
        if not df_rt.empty:
            segments["Realtime"] = df_rt
        else:
            print("[skip] realtime segment empty after trimming")
    else:
        print("[skip] realtime not available")

    # daily runs: D0..D-3
    for age in range(0, 4):
        run_day_dt = t0_today_dt - timedelta(days=age)
        t0_run = pd.Timestamp(day_start_6am(run_day_dt))

        df_daily = load_daily_earth_for_date(run_day_dt)
        if df_daily is None:
            continue  # <- IMPORTANT: don't crash, just skip

        horizon_days = 4 - age
        df_seg = slice_shift_horizon(df_daily, t0_run=t0_run, t0_today=t0_today, horizon_days=horizon_days)

        if df_seg is None or df_seg.empty:
            print(f"[skip] Daily D-{age} empty after slice/shift")
            continue

        segments[f"Daily D-{age}" if age else "Daily D0"] = df_seg

    if not segments:
        print("[warning] no segments available to plot (all missing/empty)")
    return t0_today, segments

def plot_earth_multi(segments: dict, df_real: pd.DataFrame, out_folder: str, t0_today: pd.Timestamp):
    """
    segments keys: "Realtime", "Daily D0", "Daily D-1", "Daily D-2", "Daily D-3"
    each value is a df indexed by shifted time (today-axis)
    """

    utc_now = pd.Timestamp(datetime.utcnow())

    # Determine plot window: [today 06:00, today 06:00 + 4d)
    t_start = t0_today
    t_end = t0_today + pd.Timedelta(days=4)

    # ACE trim to plot window (today-axis)
    df_real_trimmed = df_real.loc[(df_real.index >= t_start) & (df_real.index <= t_end)].copy()
    for col in ['velocity_real', 'density_real', 'temperature_real', 'Bmag_real']:
        df_real_trimmed[col] = df_real_trimmed[col].rolling(window=10, center=True, min_periods=1).median()

    central_time = t_start + (t_end - t_start) / 2
    df_real_before = df_real_trimmed[df_real_trimmed.index <= central_time]
    df_real_after  = df_real_trimmed[df_real_trimmed.index >  central_time]

    label_fontsize = 14
    tick_fontsize = 14
    colorbar_fontsize = 14
    legend_fontsize = 10

    plt.rcParams.update({
    "font.size": 12,
    "axes.labelsize": 12,
    "legend.fontsize": 10,
    "axes.titlesize": label_fontsize,
    "xtick.labelsize": label_fontsize,
    "ytick.labelsize": label_fontsize,
    })

    fig, axs = plt.subplots(4, 1, figsize=(7.2, 6), sharex=True)
    fig.patch.set_facecolor('#f5f7fa')
    fig.suptitle("Solar Wind parameters at Earth", fontsize=label_fontsize)

    for ax in axs:
        ax.axvline(
            utc_now,
            linestyle="--",
            linewidth=2,
            color="purple",
            label="Current time (UTC)"
    )

    # Styles (tweak as you like)
    style = {
        "Realtime": dict(color="black", linewidth=2.0, label="Realtime"),
        "Daily D0": dict(color="tab:red", linewidth=2.0, label="Daily (today)"),
        "Daily D-1": dict(color="tab:orange", linewidth=1.8, label="Daily (yesterday)"),
        "Daily D-2": dict(color="tab:green", linewidth=1.8, label="Daily (2 days ago)"),
        "Daily D-3": dict(color="tab:blue", linewidth=1.8, label="Daily (3 days ago)"),
    }

    # Helper to plot all segments for a given column
    def plot_segments(ax, ycol, ylabel, logy=False):
        for name, df in segments.items():
            if df is None or df.empty or ycol not in df.columns:
                continue
            kw = style.get(name, {})
            ax.plot(df.index.values, df[ycol].values, **kw)

        # ACE overlay
        if not df_real_before.empty:
            ax.plot(df_real_before.index.values, df_real_before[{
                "V_mag":"velocity_real",
                "rho_conv":"density_real",
                "temp_calc_K":"temperature_real",
                "B_mag":"Bmag_real"
            }[ycol]].values, color="gray", label="ACE")

        if not df_real_after.empty:
            ax.plot(df_real_after.index.values, df_real_after[{
                "V_mag":"velocity_real",
                "rho_conv":"density_real",
                "temp_calc_K":"temperature_real",
                "B_mag":"Bmag_real"
            }[ycol]].values, color="cyan", linestyle="--", label="ACE (post-window)")

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

    start_time_str = t_start.strftime("Start time: %Y-%m-%d %H:%M")
    #axs[3].set_xlabel(start_time_str, fontsize=label_fontsize)
    
    axs[3].text(
        0.99, 0.02,
        start_time_str,
        transform=axs[3].transAxes,
        ha="right",
        va="bottom",
        fontsize=label_fontsize-4,
        alpha=0.7,
        color="black",
    )

    # X ticks: every 12 hours or daily
    axs[3].xaxis.set_major_locator(mdates.DayLocator(interval=1))
    axs[3].xaxis.set_minor_locator(mdates.HourLocator(interval=6))
    axs[3].xaxis.set_major_formatter(mdates.DateFormatter('%d-%b'))
    axs[3].tick_params(axis='x', which='major', length=8, width=1.5)
    axs[3].tick_params(axis='x', which='minor', length=4, width=1)

    for ax in axs:
        ax.set_xlim(t_start, t_end)

    # One shared legend
    handles, labels = axs[0].get_legend_handles_labels()
    for ax in axs:
        leg = ax.legend()
        if leg:
            leg.remove()

    fig.legend(
    handles,
    labels,
    loc='lower center',
    bbox_to_anchor=(0.5, 0.01),  # inside figure bottom
    ncol=4,
    prop={'size': 8},
    markerscale=0.7,
    )


    #fig.legend(handles, labels, loc='upper center', bbox_to_anchor=(0.5, 0.94), ncol=3)

    plt.tight_layout(rect=[0, 0.08, 1, 0.97])
    #rect=[0, 0, 1, 0.97]
    os.makedirs(out_folder, exist_ok=True)
    outpath = os.path.join(out_folder, "Earth.png")
    plt.savefig(outpath, dpi=300)

def main():
    now = datetime.now()

    # output folder
    out_folder = "/data/Simulations/gergelyk/Daily_SW/Website/data/PIPELINE/REALTIME/"

    # ACE file same as before
    ace_file = "/data/Simulations/gergelyk/Daily_SW/27days_SW.txt"
    df_ace = read_ace_data(ace_file)

    # realtime sat file path (replace with your actual realtime file location)
    realtime_file = "/data/Simulations/gergelyk/Daily_SW/AWSRT/Realtime_BG_results/sat_earth_realtime.sat"

    t0_today, segments = build_segments(now, realtime_file)

    plot_earth_multi(segments, df_ace, out_folder=out_folder, t0_today=t0_today)

if __name__ == "__main__":
    main()

