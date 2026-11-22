"""Summarise sampling in the Sonso and Mpala waking records without fitting models."""

import argparse
import csv
import json
from collections import Counter, defaultdict
from datetime import date, datetime
from itertools import combinations
from math import isfinite
from pathlib import Path
from statistics import median

from openpyxl import load_workbook


def read_sonso(workbook_path):
    workbook = load_workbook(workbook_path, read_only=True, data_only=True)
    try:
        rows = workbook["SLEEP"].values
        header = next(rows)
        animal, night, waking = (header.index(name) for name in ("Id", "Date", "Wake_time"))
        records = []
        for row in rows:
            value = row[waking]
            if not isinstance(value, (int, float)) or isinstance(value, bool) or not isfinite(value):
                continue
            if not row[animal] or not isinstance(row[night], datetime) or not 0 <= value < 12:
                raise ValueError("A Sonso waking row lacks a valid animal, date, or morning time")
            records.append((row[animal], row[night].date()))
        return records
    finally:
        workbook.close()


def read_mpala(csv_path):
    with csv_path.open(newline="") as source:
        records = []
        for row in csv.DictReader(source):
            night = date.fromisoformat(row["night_date"])
            waking = datetime.fromisoformat(row["waking_local"])
            if not row["tag"] or (waking.date() - night).days not in (0, 1):
                raise ValueError("A Mpala waking row lacks a valid tag or noon-to-noon date")
            records.append((row["tag"], night))
        return records


def describe(records, longer_lag_end):
    if not records or len(records) != len(set(records)):
        raise ValueError("Expected one waking record per recorded animal and date")
    nights_by_animal = defaultdict(list)
    for animal, night in records:
        nights_by_animal[animal].append(night)
    nights = Counter(night for _, night in records)
    repeated = [sorted(dates) for dates in nights_by_animal.values() if len(dates) > 1]
    spans = [(dates[-1] - dates[0]).days for dates in repeated]
    lags = [[(end - start).days for start, end in combinations(dates, 2)] for dates in repeated]
    return {
        "records": len(records),
        "animals": len(nights_by_animal),
        "animals_with_repeat_records": len(repeated),
        "dates": len(nights),
        "dates_with_multiple_animals": sum(count > 1 for count in nights.values()),
        "median_records_per_animal": median(map(len, nights_by_animal.values())),
        "median_days_spanned_by_repeated_animals": median(spans) if spans else None,
        "animals_with_both_short_and_long_lags": sum(
            any(lag < 14 for lag in offsets) and any(14 <= lag <= longer_lag_end for lag in offsets)
            for offsets in lags
        ),
        "date_range": [min(nights).isoformat(), max(nights).isoformat()],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sonso_workbook", type=Path)
    parser.add_argument(
        "--mpala-records", type=Path, default=Path("analysis/results/baboon-sleep-pairs.csv")
    )
    args = parser.parse_args()
    sonso = read_sonso(args.sonso_workbook)
    mpala = read_mpala(args.mpala_records)
    # The existing analysis uses 14-day blocks. Use the longest Mpala
    # within-animal lag as the upper bound when screening for overlapping lags.
    mpala_spans = defaultdict(list)
    for animal, night in mpala:
        mpala_spans[animal].append(night)
    longest_mpala_lag = max((max(nights) - min(nights)).days for nights in mpala_spans.values())
    print(json.dumps({
        "short_lag_days": [1, 13],
        "longer_shared_lag_days": [14, longest_mpala_lag],
        "sonso": describe(sonso, longest_mpala_lag),
        "mpala": describe(mpala, longest_mpala_lag),
    }, indent=2))


if __name__ == "__main__":
    main()
