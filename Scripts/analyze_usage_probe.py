#!/usr/bin/env python3
"""Summarize real DeviceActivity receipt times; never equate them to app transitions."""
import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("log", type=Path)
args = parser.parse_args()
entries = json.loads(args.log.read_text())
epoch = datetime(2001, 1, 1, tzinfo=timezone.utc)
registrations = {}
previous = {}
flags = []
print("UTC time                     event                 usage   wall Δ   usage Δ")
for entry in entries:
    time = entry["time"]
    kind = entry["kind"]
    activity = entry["activity"]
    value = entry.get("usageSeconds")
    stamp = (epoch + timedelta(seconds=time)).isoformat(timespec="milliseconds")
    wall_delta = usage_delta = None
    if kind == "register":
        registrations[activity] = time
    if kind == "threshold" and value is not None:
        if activity in previous:
            last_time, last_value = previous[activity]
            wall_delta, usage_delta = time - last_time, value - last_value
            if usage_delta <= 0:
                flags.append(f"{stamp}: duplicate/out-of-order threshold")
            elif wall_delta < 1 and usage_delta >= 10:
                flags.append(f"{stamp}: batched delivery; cannot treat receipt time as usage time")
        if activity in registrations and value > time - registrations[activity] + 10:
            flags.append(f"{stamp}: reported usage exceeds elapsed time since fresh registration")
        previous[activity] = (time, value)
    delta = lambda v: "—" if v is None else f"{v:.1f}"
    print(f"{stamp}  {kind:22} {str(value) if value is not None else '—':>5} {delta(wall_delta):>9} {delta(usage_delta):>9}")
print(f"\n{len(entries)} entries; {sum(e['kind'] == 'threshold' for e in entries)} usage callbacks.")
for flag in flags:
    print("CHECK:", flag)
print("Receipt gaps are observations, not proven app-open/close times. Compare with the operator's recorded actions.")
