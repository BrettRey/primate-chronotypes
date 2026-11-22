"""Recover baboon sleep-period endpoints from the 2012 or Laikipia ACC archive."""

import argparse
import csv
from collections import defaultdict
from datetime import datetime, timedelta
import hashlib
from io import TextIOWrapper
from itertools import groupby
from pathlib import Path
from zipfile import ZipFile

import numpy as np


# The next part repeats the events at 00:00 UTC on each shared boundary.
ARCHIVE_PARTS = (
    ("3c36bb3880bf93097c2b94904a958409", "2012-08-08"),
    ("5503df6affda6c32f7d3bfcb1ef99bd7", "2012-08-15"),
    ("2481c5f2590a88aab66d810703bf8a4b", "2012-08-22"),
    ("5902b97dde332b2f352a43e72e3f5d3c", "2012-09-05"),
)
LOCAL_OFFSET = timedelta(hours=3)
LAIKIPIA_MD5 = "58249568cfe7c09d1dd953aaf18c1242"
LAIKIPIA_MEMBER = "Leopards vervets and baboons in Laikipia Kenya_part-acc.csv"
SOURCE_GRID = np.linspace(0, 1, 13)[:12]
DAYTIME_GRID = np.arange(10) / 10


def selected_rows(reader, stop_date):
    columns = next(reader)
    tag_col = columns.index("tag-local-identifier")
    time_col = columns.index("timestamp")
    acc_col = columns.index("eobs:accelerations-raw")
    for row in reader:
        timestamp = row[time_col]
        if timestamp[:10] < stop_date and row[acc_col] and int(timestamp[17:19]) < 12:
            yield (row[tag_col], timestamp[:16]), timestamp[17:], row[acc_col]


def minute_samples(rows):
    # The notebook selects the first three consecutive seconds, or the first
    # burst if no such triplet exists. Night bursts already have 26 XYZ samples.
    rows = sorted(rows, key=lambda row: row[1])
    milliseconds = [int(row[1].replace(".", "")) for row in rows]
    for start in range(len(rows) - 2):
        if (milliseconds[start + 1] - milliseconds[start] == 1000
                and milliseconds[start + 2] - milliseconds[start + 1] == 1000):
            chosen = rows[start:start + 3]
            break
    else:
        chosen = rows[:1]

    samples = []
    for _, _, raw in chosen:
        values = np.fromstring(raw, sep=" ")
        if values.size == 36:
            axes = values.reshape(12, 3)
            values = np.column_stack([
                np.interp(DAYTIME_GRID, SOURCE_GRID, axis) for axis in axes.T
            ]).ravel()
        samples.append(values)
    combined = np.concatenate(samples)[:78] if len(chosen) == 3 else samples[0]
    if combined.size == 78:
        return combined.reshape(26, 3)
    return None


def log_vedba(samples):
    # Average the norm of the three dynamic axes, each centred by its own
    # seven-sample moving mean. The window shrinks at either edge.
    cumulative = np.pad(samples.cumsum(axis=1), ((0, 0), (1, 0), (0, 0)))
    n_samples = samples.shape[1]
    index = np.arange(n_samples)
    left, right = np.maximum(index - 3, 0), np.minimum(index + 4, n_samples)
    static = (cumulative[:, right] - cumulative[:, left]) / (right - left)[None, :, None]
    with np.errstate(divide="ignore"):
        return np.log(np.linalg.norm(samples - static, axis=2).mean(axis=1))


def read_minutes(directory):
    minutes = {}
    for index, (expected, stop_date) in enumerate(ARCHIVE_PARTS, start=1):
        path = directory / f"Collective movement in wild baboons-acc-{index}of4.csv.zip"
        with path.open("rb") as source:
            digest = hashlib.file_digest(source, "md5").hexdigest()
        if digest != expected:
            raise ValueError(f"Movebank checksum differs for {path}")

        with ZipFile(path) as archive, TextIOWrapper(archive.open(path.stem), newline="") as source:
            # Movebank's CSVs are ordered in blocks of tag and timestamp.
            batch_keys, batch = [], []
            seen = set()
            events = selected_rows(csv.reader(source), stop_date)
            for key, rows in groupby(events, key=lambda row: row[0]):
                if key in seen or key in minutes:
                    raise ValueError(f"Noncontiguous or repeated tag-minute {key}")
                seen.add(key)
                samples = minute_samples(list(rows))
                if samples is not None:
                    batch.append(samples)
                    batch_keys.append(key)
                if len(batch) == 10000:
                    minutes.update(zip(batch_keys, log_vedba(np.stack(batch))))
                    batch_keys.clear()
                    batch.clear()
            if batch:
                minutes.update(zip(batch_keys, log_vedba(np.stack(batch))))
        print(f"Read {path.name} ({len(minutes):,} usable minutes so far)", flush=True)
    return minutes


def read_laikipia_minutes(path):
    with path.open("rb") as source:
        if hashlib.file_digest(source, "md5").hexdigest() != LAIKIPIA_MD5:
            raise ValueError(f"Movebank checksum differs for {path}")

    minutes = {}
    skipped_bursts = skipped_illness = 0
    batch, keys = [], []

    def flush():
        if len(set(keys)) != len(keys) or any(key in minutes for key in keys):
            raise ValueError("Repeated Laikipia animal-minute")
        minutes.update(zip(keys, log_vedba(np.stack(batch))))
        keys.clear()
        batch.clear()

    with ZipFile(path) as archive, TextIOWrapper(archive.open(LAIKIPIA_MEMBER), newline="") as source:
        reader = csv.DictReader(source)
        for row in reader:
            tag, minute = row["individual-local-identifier"], row["timestamp"][:16]
            if not tag or row["individual-taxon-canonical-name"] != "Papio anubis":
                raise ValueError("Unexpected Laikipia animal identifier or taxon")
            # The study discards this animal's records from 28 May local time.
            if tag == "Pa LI TH" and minute >= "2014-05-27 21:00":
                skipped_illness += 1
                continue
            samples = np.fromstring(row["eobs:accelerations-raw"], sep=" ")
            if samples.size != 120:
                skipped_bursts += 1
                continue
            if row["eobs:acceleration-axes"] != "XYZ" or not np.all(np.isfinite(samples)):
                raise ValueError(f"Invalid Laikipia acceleration burst for {tag} at {minute}")
            keys.append((tag, minute))
            batch.append(samples.reshape(40, 3))
            if len(batch) == 10000:
                flush()
        if batch:
            flush()

    print(f"Read {len(minutes):,} minutes from {path.name}, "
          f"excluding {skipped_bursts:,} incomplete bursts and "
          f"{skipped_illness:,} minutes under the source illness exclusion", flush=True)
    return minutes


def endpoints(timestamps, log_activity):
    if len(timestamps) < 9:
        return None
    smoothed = np.median(np.lib.stride_tricks.sliding_window_view(log_activity, 9), axis=1)
    inactive = smoothed < 1.125 * np.quantile(smoothed, 0.10)
    edges = np.flatnonzero(np.diff(np.r_[False, inactive, False]))
    periods = []
    for start, end in edges.reshape(-1, 2):
        if end - start <= 30:
            continue
        # The R code indexes the first epoch after the block as its endpoint.
        begin, finish = timestamps[start + 4], timestamps[end + 4]
        if periods and begin - periods[-1][1] < timedelta(minutes=45):
            periods[-1] = (periods[-1][0], finish)
        else:
            periods.append((begin, finish))
    return max(periods, key=lambda p: p[1] - p[0], default=None)


def summarize(minutes):
    nights = defaultdict(list)
    for (tag, minute), activity in sorted(minutes.items()):
        local_time = datetime.fromisoformat(minute) + LOCAL_OFFSET
        night = (local_time - timedelta(hours=12)).date()
        nights[tag, night].append((local_time, activity))

    paired = []
    candidate_count = coverage_count = 0
    for (tag, night), values in sorted(nights.items()):
        timestamps, activity = zip(*values)
        period = endpoints(timestamps, activity)
        if period is None:
            continue
        candidate_count += 1
        if len(values) < 1440 - 120:
            continue
        coverage_count += 1
        # Match the R code's clock-minute ordering and its boundary sentinels.
        clock_minutes = sorted(t.hour * 60 + t.minute for t in timestamps)
        if max(np.diff([0, *clock_minutes, 1439])) > 20:
            continue
        onset, waking = period
        paired.append((tag, night, onset, waking, len(values)))

    print(f"{len(nights)} recorded tag-nights → {candidate_count} sleep periods"
          f" → {coverage_count} after the coverage rule → {len(paired)} after the gap rule")
    return paired


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("movebank_path", type=Path, help="2012 directory or Laikipia acceleration ZIP")
    parser.add_argument("output", type=Path)
    parser.add_argument("--laikipia", action="store_true", help="Read the 2014–2015 archive")
    args = parser.parse_args()
    read = read_laikipia_minutes if args.laikipia else read_minutes
    rows = summarize(read(args.movebank_path))
    with args.output.open("w", newline="") as destination:
        writer = csv.writer(destination, lineterminator="\n")
        writer.writerow(("tag", "night_date", "onset_local", "waking_local", "n_bursts"))
        writer.writerows(rows)


if __name__ == "__main__":
    main()
