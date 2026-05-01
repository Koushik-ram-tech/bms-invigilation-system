import re
import json
import logging
from typing import List, Dict

# ─────────────────────────────────────────────
# LOGGING (PRODUCTION LEVEL)
# ─────────────────────────────────────────────
import logging
import os

# Ensure log directory exists
LOG_DIR = os.path.join(os.path.dirname(__file__), "config")
os.makedirs(LOG_DIR, exist_ok=True)

LOG_FILE = os.path.join(LOG_DIR, "logs.txt")

logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)

def log_info(msg):
    print(msg)
    logging.info(msg)

def log_error(msg):
    print("ERROR:", msg)
    logging.error(msg)


# ─────────────────────────────────────────────
# NORMALISE USN (BULLETPROOF)
# ─────────────────────────────────────────────
def normalise_usn(usn: str) -> str:
    if not usn:
        return ""

    # Step 1: uppercase
    usn = usn.upper()

    # Step 2: remove spaces
    usn = re.sub(r"\s+", "", usn)

    # Step 3: fix OCR mistakes ONLY in numeric section
    match = re.match(r'([A-Z]+)(\d+.*)', usn)
    if match:
        prefix, rest = match.groups()
        rest = rest.replace("O", "0")
        usn = prefix + rest

    return usn


# ─────────────────────────────────────────────
# REBUILD ROOM USN RANGES
# ─────────────────────────────────────────────
def rebuild_rooms_with_prefix(rooms: List[Dict], prefix: str, total: int):
    rebuilt = []
    counter = 1

    for r in rooms:
        count = int(r.get("students", 0))

        start = f"{prefix}{str(counter).zfill(3)}"
        end   = f"{prefix}{str(counter + count - 1).zfill(3)}"

        rebuilt.append({
            "room": r["room"],
            "students": count,
            "usn_start": start,
            "usn_end": end,
            "usn_range": f"{start}-{end[-3:]}"
        })

        counter += count

    return rebuilt