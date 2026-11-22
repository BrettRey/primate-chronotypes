"""Report the time coverage of the published 2019 thermal-video scores."""

import argparse
import csv
from datetime import datetime, timedelta
import hashlib
from pathlib import Path


SHA256 = "7db9109bd24a5a358fc1719da33f1ba325e0c8ccb2cc5e17f4220bd239edaea3"
LOCAL_CORRECTION = timedelta(hours=3, seconds=16)
NOON = timedelta(hours=12)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scoring_csv", type=Path)
    args = parser.parse_args()
    with args.scoring_csv.open("rb") as source:
        if hashlib.file_digest(source, "sha256").hexdigest() != SHA256:
            raise ValueError("Expected the Dryad version 6 behavioural scoring CSV")

    with args.scoring_csv.open(newline="") as source:
        intervals = [
            (row["collar_id"], row["Value"],
             datetime.fromisoformat(row["start_timestamp"]) + LOCAL_CORRECTION,
             datetime.fromisoformat(row["stop_timestamp"]) + LOCAL_CORRECTION)
            for row in csv.DictReader(source)
        ]
    nights = {(start - NOON).date() for _, _, start, _ in intervals}
    collars = {tag for tag, _, _, _ in intervals}
    sleep_collars = {tag for tag, state, _, _ in intervals if state == "Unalert"}
    latest_clock = max(stop.time() for _, _, _, stop in intervals)
    morning_intervals = sum((start - NOON).date() < stop.date()
                            for _, _, start, stop in intervals)
    print(f"{len(intervals)} scored intervals across {len(collars)} collars and {len(nights)} nights")
    print("Night dates:", ", ".join(str(night) for night in sorted(nights)))
    print("Latest local scoring time:", latest_clock.strftime("%H:%M:%S"))
    print("Intervals reaching the following morning:", morning_intervals)
    print("Collars with any sleep-coded (Unalert) intervals:", len(sleep_collars))


if __name__ == "__main__":
    main()
