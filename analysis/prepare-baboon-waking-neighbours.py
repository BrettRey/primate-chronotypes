"""Join morning telemetry to the reconstructed baboon waking endpoints."""

import argparse
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor
import csv
from datetime import date, datetime, time, timedelta
import hashlib
from pathlib import Path
from runpy import run_path
from zipfile import ZipFile

import numpy as np


recovery = run_path(str(Path(__file__).with_name("recover-baboon-sleep.py")))
GPS_MD5 = (
    "ddeffe5a8efd7438019c431cf20cec2c",
    "0d3215228d1bc07b722b1bb2067723c4",
    "648b1275c680e4a9bbd5e91b400a6a70",
    "2b219a3620034b7c27ab7298874cc885",
)
UTC_ACTIVITY_MINUTES = ("03:02", "03:03", "03:04")
FORECAST_TIME = time(6, 5)
DISTANCE_SCALES = (15, 30)


def morning_telemetry(job):
    directory, source_type, part, expected = job
    path = directory / f"Collective movement in wild baboons-{source_type}-{part}of4.csv.zip"
    with path.open("rb") as source:
        if hashlib.file_digest(source, "md5").hexdigest() != expected:
            raise ValueError(f"Movebank checksum differs for {path}")

    groups = defaultdict(list)
    with ZipFile(path) as archive, archive.open(path.stem) as source:
        columns = source.readline().decode().strip().split(",")
        tag_col = columns.index("tag-local-identifier")
        if columns.index("timestamp") != 2:
            raise ValueError(f"Unexpected timestamp column in {path}")
        gps = source_type == "gps"
        if gps:
            lon_col = columns.index("location-long")
            lat_col = columns.index("location-lat")
        else:
            acc_col = columns.index("eobs:accelerations-raw")

        # Check the UTC clock field before parsing the full telemetry row.
        for raw in source:
            timestamp = raw.split(b",", 3)[2]
            clock = timestamp[11:19]
            if gps and b"03:00:00" <= clock < b"03:02:00":
                row = next(csv.reader([raw.decode()]))
                if row[lon_col] and row[lat_col]:
                    position = (float(row[lon_col]), float(row[lat_col]))
                    if np.isfinite(position).all():
                        groups[row[tag_col], timestamp[:10].decode()].append((timestamp, position))
            if not gps and b"03:02:00" <= clock < b"03:05:00" and timestamp[17:19] < b"12":
                row = next(csv.reader([raw.decode()]))
                if row[acc_col]:
                    key = (row[tag_col], timestamp[:16].decode())
                    groups[key].append((key, timestamp[17:].decode(), row[acc_col]))

    if gps:
        positions = {}
        for key, fixes in groups.items():
            by_timestamp = dict(fixes)
            if len(by_timestamp) >= 10:
                positions[key] = np.median([p for _, p in sorted(by_timestamp.items())[:10]], axis=0)
        return positions

    motion = {}
    for key, rows in groups.items():
        samples = recovery["minute_samples"](rows)
        if samples is not None:
            activity = recovery["log_vedba"](samples[None, :, :])[0]
            if np.isfinite(activity):
                motion[key] = activity
    return motion


def paired_features(pairs, positions, motion):
    peers_by_morning = defaultdict(dict)
    for (tag, morning), position in positions.items():
        minute_keys = [(tag, f"{morning} {clock}") for clock in UTC_ACTIVITY_MINUTES]
        if all(key in motion for key in minute_keys):
            peers_by_morning[morning][tag] = position, np.mean([motion[key] for key in minute_keys])

    records, counts = [], defaultdict(int)
    for row in pairs:
        tag = row["tag"]
        morning = date.fromisoformat(row["night_date"]) + timedelta(days=1)
        landmark = datetime.combine(morning, FORECAST_TIME)
        remaining = (datetime.fromisoformat(row["waking_local"]) - landmark).total_seconds() / 60
        if remaining <= 0:
            counts["endpoint at or before forecast"] += 1
            continue
        peers = peers_by_morning[morning.isoformat()]
        if tag not in peers:
            counts["missing focal telemetry"] += 1
            continue
        if len(peers) < 2:
            counts["no peers with telemetry"] += 1
            continue

        position, focal_motion = peers[tag]
        peer_positions, peer_motion = zip(*(v for t, v in peers.items() if t != tag))
        # A local planar approximation is adequate at the distances in one sleep site.
        offset = np.asarray(peer_positions) - position
        latitude = (np.asarray(peer_positions)[:, 1] + position[1]) / 2
        distance = 111195 * np.hypot(offset[:, 0] * np.cos(np.radians(latitude)), offset[:, 1])
        all_peer_motion = np.mean(peer_motion)
        contrasts = {}
        for scale in DISTANCE_SCALES:
            weights = np.exp(-(distance - np.min(distance)) / scale)
            contrasts[f"neighbour_contrast_{scale}m"] = (
                np.average(peer_motion, weights=weights) - all_peer_motion
            )
        records.append({
            "tag": tag, "night_date": row["night_date"], "minutes_to_wake": remaining,
            "focal_motion": focal_motion, "peer_motion": all_peer_motion, **contrasts,
            "n_peers": len(distance), "nearest_peer_m": min(distance),
            "median_peer_m": np.median(distance), "farthest_peer_m": max(distance),
        })
    return records, counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("movebank_directory", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--pairs", type=Path, default=Path("analysis/results/baboon-sleep-pairs.csv"))
    args = parser.parse_args()
    with args.pairs.open(newline="") as source:
        pairs = list(csv.DictReader(source))
    if len({(row["tag"], row["night_date"]) for row in pairs}) != len(pairs):
        raise ValueError("Repeated tag-night in the waking endpoints")
    acc_md5 = [digest for digest, _ in recovery["ARCHIVE_PARTS"]]
    jobs = [(args.movebank_directory, source_type, part, digest)
            for source_type, checksums in (("gps", GPS_MD5), ("acc", acc_md5))
            for part, digest in enumerate(checksums, start=1)]
    with ProcessPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(morning_telemetry, jobs))
    positions, motion = {}, {}
    for destination, parts in ((positions, results[:4]), (motion, results[4:])):
        for part in parts:
            if destination.keys() & part.keys():
                raise ValueError("The archive contains a repeated morning telemetry key")
            destination.update(part)

    records, counts = paired_features(pairs, positions, motion)
    if not records:
        raise ValueError("No late waking records with matched morning telemetry")
    with args.output.open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=records[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(records)
    print(f"{len(records)} eligible animal-nights out of {len(pairs)} paired endpoints")
    for reason, count in counts.items():
        print(f"{reason}: {count}")


if __name__ == "__main__":
    main()
