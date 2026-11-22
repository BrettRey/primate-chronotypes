"""Recover the scored sleep endpoints in Yang et al.'s iSleep workbook."""

import argparse
import csv
from collections import defaultdict
from datetime import datetime, timedelta
import hashlib
from io import BytesIO
from pathlib import Path
from runpy import run_path
from zipfile import ZipFile

from openpyxl import load_workbook


SUPPLEMENT_SHA256 = "3ae96a020431e4ee5be268b58ecef7dfd15c8b3e064667e10804858aa6b73de5"
MEMBER = "ANBEH-D-25-00495 data and code/iSleep.xlsx"


def read_periods(path):
    with path.open("rb") as source:
        if hashlib.file_digest(source, "sha256").hexdigest() != SUPPLEMENT_SHA256:
            raise ValueError(f"Publisher supplement checksum differs for {path}")
    with ZipFile(path) as archive:
        workbook = load_workbook(BytesIO(archive.read(MEMBER)), read_only=True, data_only=True)
    periods = defaultdict(list)
    try:
        rows = workbook.active.values
        if next(rows) != ("Date", "Time", "ID", "state", "Behavior", "S1eepperiod", "Dateperiod"):
            raise ValueError("Unexpected macaque workbook columns")
        for day, clock, animal, state, behavior, period, _ in rows:
            if isinstance(clock, datetime):
                clock = clock.time()
            stamp = datetime.combine(datetime.strptime(str(day), "%Y%m%d").date(), clock)
            if state not in (0, 1) or (state == 1) != (behavior == "SL"):
                raise ValueError(f"Inconsistent sleep score in period {period}")
            periods[period].append((stamp, animal, state))
    finally:
        workbook.close()
    return periods


def recover(periods, bout_periods=None):
    one_minute = timedelta(minutes=1)
    results = {}
    for period, rows in periods.items():
        rows.sort()
        stamps, animals, states = zip(*rows)
        if len(set(animals)) != 1 or any(b - a != one_minute for a, b in zip(stamps, stamps[1:])):
            raise ValueError(f"Expected consecutive minutes from one animal in period {period}")
        asleep = [index for index, state in enumerate(states) if state == 1]
        if not asleep or asleep[-1] + 1 == len(stamps):
            raise ValueError(f"Missing a scored sleep-to-wake transition in period {period}")
        onset, waking = stamps[asleep[0]], stamps[asleep[-1] + 1]
        key = (animals[0], (waking - timedelta(hours=12)).date())
        if key in results:
            raise ValueError(f"Repeated animal-night {key}")
        row = (onset, waking, int((stamps[-1] - waking) / one_minute))
        if bout_periods is not None:
            candidates = bout_periods(stamps, states)
            if not candidates:
                row += (None, None, None)
            else:
                _, longest_end = max(candidates, key=lambda p: p[1] - p[0])
                last_end = candidates[-1][1]
                row += (longest_end, int((waking - longest_end) / one_minute), last_end)
        results[key] = row
    return [(animal, date, *results[animal, date]) for animal, date in sorted(results)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("supplement_zip", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--compare-endpoints", action="store_true",
                        help="Also apply the baboon bout-selection rules to the video scores")
    args = parser.parse_args()
    header = ("tag", "night_date", "onset_local", "waking_local", "minutes_after_waking")
    bout_periods = None
    if args.compare_endpoints:
        classifier = run_path(str(Path(__file__).with_name("recover-baboon-sleep.py")))
        bout_periods = classifier["sleep_periods_from_states"]
        header += ("longest_period_end_local", "minutes_earlier", "last_qualifying_period_end_local")
    rows = recover(read_periods(args.supplement_zip), bout_periods)
    with args.output.open("w", newline="") as destination:
        writer = csv.writer(destination, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)
    print(f"Recovered {len(rows)} scored macaque animal-nights.")


if __name__ == "__main__":
    main()
