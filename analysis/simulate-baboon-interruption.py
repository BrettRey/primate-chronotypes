"""Demonstrate how an interruption can change the classified sleep endpoint."""

import argparse
import csv
from datetime import datetime, timedelta
from pathlib import Path
from runpy import run_path

import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_csv", type=Path)
    args = parser.parse_args()
    recovery = run_path(str(Path(__file__).with_name("recover-baboon-sleep.py")))

    noon = datetime(2000, 1, 1, 12)
    minute = timedelta(minutes=1)
    timestamps = [noon + i * minute for i in range(24 * 60)]
    bedtime, morning = 8 * 60, 18 * 60
    uninterrupted = np.full(len(timestamps), 5.0)
    uninterrupted[bedtime:morning] = 2.0
    results = []
    for start, duration in ((None, 0), (13 * 60, 44), (13 * 60, 45), (11 * 60, 45)):
        activity = uninterrupted.copy()
        if start is not None:
            activity[start:start + duration] = 5.0
        onset, end = recovery["endpoints"](timestamps, activity)
        simulated_waking = timestamps[morning]
        results.append((
            timestamps[start].strftime("%H:%M") if start is not None else "",
            duration,
            simulated_waking.strftime("%H:%M"),
            onset.strftime("%H:%M"),
            end.strftime("%H:%M"),
            int((simulated_waking - end) / minute),
        ))
    with args.output_csv.open("w", newline="") as destination:
        writer = csv.writer(destination, lineterminator="\n")
        writer.writerow(("interruption_starts", "interruption_minutes", "simulated_morning_waking",
                         "classified_onset", "classified_end", "classified_end_minutes_early"))
        writer.writerows(results)


if __name__ == "__main__":
    main()
