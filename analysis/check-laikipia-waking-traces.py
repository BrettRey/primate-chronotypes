"""Trace Laikipia endpoints before midnight and list later classified sleep periods."""

import argparse
import csv
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from runpy import run_path


recovery = run_path(str(Path(__file__).with_name("recover-baboon-sleep.py")))
LOCAL_OFFSET = recovery["LOCAL_OFFSET"]
ONE_MINUTE = timedelta(minutes=1)
HALF_DAY = timedelta(hours=12)


def read_cases(path):
    with path.open(newline="") as source:
        records = list(csv.DictReader(source))
    early = [row for row in records if row["waking_local"][:10] == row["night_date"]]
    example_night = min(early, key=lambda row: row["waking_local"][11:])["night_date"]
    cases = {(row["tag"], row["night_date"]): row for row in early}
    cases.update({(row["tag"], row["night_date"]): row for row in records
                  if row["night_date"] == example_night})
    return cases, example_night


def read_traces(path, cases):
    selected_minutes = set()
    for tag, night in cases:
        utc_noon = datetime.fromisoformat(night) + HALF_DAY - LOCAL_OFFSET
        selected_minutes.update(
            (tag, (utc_noon + ONE_MINUTE * minute).isoformat(sep=" ", timespec="minutes"))
            for minute in range(1440)
        )
    traces = defaultdict(list)
    for (tag, minute), activity in sorted(
        recovery["read_laikipia_minutes"](path, selected_minutes).items()
    ):
        local = datetime.fromisoformat(minute) + LOCAL_OFFSET
        night = (local - HALF_DAY).date().isoformat()
        traces[tag, night].append((local, activity))
    return traces


def write_audit(cases, traces, example_night, summary_path, trace_path):
    with summary_path.open("w", newline="") as summary, trace_path.open("w", newline="") as example:
        results = csv.writer(summary, lineterminator="\n")
        results.writerow(("tag", "night_date", "onset_local", "classified_waking_local",
                          "bursts_after_waking", "later_periods", "first_later_onset_local",
                          "last_later_end_local", "longest_later_period_minutes"))
        points = csv.writer(example, lineterminator="\n")
        points.writerow(("tag", "local_time", "log_vedba", "classified_period"))
        for (tag, night), record in sorted(cases.items()):
            times, activity = zip(*traces[tag, night])
            periods = recovery["sleep_periods"](times, activity)
            selected = max(periods, key=lambda bounds: bounds[1] - bounds[0])
            onset, wake = selected
            expected = tuple(datetime.fromisoformat(record[field])
                             for field in ("onset_local", "waking_local"))
            if selected != expected or len(times) != int(record["n_bursts"]):
                raise ValueError(f"Reconstructed endpoint or coverage differs for {tag}, {night}")
            later = [(start, end) for start, end in periods if start > wake]
            results.writerow((tag, night, onset, wake, sum(time > wake for time in times), len(later),
                              later[0][0] if later else "",
                              later[-1][1] if later else "",
                              max(((end - start) / ONE_MINUTE for start, end in later), default=0)))
            if night == example_night:
                for time, value in traces[tag, night]:
                    label = ""
                    if onset <= time <= wake:
                        label = "selected"
                    elif any(start <= time <= end for start, end in later):
                        label = "later"
                    points.writerow((tag, time, value, label))
    print(f"Verified {len(cases)} endpoints from raw bursts, including the same-night comparison.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("acceleration_zip", type=Path)
    parser.add_argument("endpoint_table", type=Path)
    parser.add_argument("summary_output", type=Path)
    parser.add_argument("example_trace_output", type=Path)
    args = parser.parse_args()
    cases, example_night = read_cases(args.endpoint_table)
    traces = read_traces(args.acceleration_zip, cases)
    write_audit(cases, traces, example_night, args.summary_output, args.example_trace_output)


if __name__ == "__main__":
    main()
