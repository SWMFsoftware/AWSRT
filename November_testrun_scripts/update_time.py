#!/usr/bin/env python3

import json
from datetime import datetime, timedelta

FILENAME = "/nobackupp28/gkoban/Realtime/SWMF/SUBMISSION_DATA/time.json"

# Read JSON
with open(FILENAME, "r") as f:
    data = json.load(f)

# Parse current_time (ISO 8601)
current_time = datetime.fromisoformat(data["current_time"])

# Advance by 1 hour
current_time += timedelta(hours=1)

# Update JSON (preserve ISO format)
data["current_time"] = current_time.isoformat(timespec="minutes")

# Write back
with open(FILENAME, "w") as f:
    json.dump(data, f, indent=2)

print(f"Updated current_time to {data['current_time']}")
