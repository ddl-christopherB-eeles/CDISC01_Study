#!/usr/bin/env python3
"""Snapshot the seeded SDTM domain files in a project dataset.

Flow tasks mount the latest read-only snapshot of each project dataset, not
its live read-write copy, so the seeded files have to be in an active
snapshot before the flow is launched.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.environ.get("DOMINO_WORKING_DIR", "/mnt/code"))

from flows.scale_profiles import SDTM_DOMAINS  # noqa: E402

POLL_INTERVAL_S = 10
TIMEOUT_S = 1800
TERMINAL_FAILURE_STATUSES = {"failed", "markForDeletion", "deletionInProgress", "deleted"}


def _request(method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        f"{os.environ['DOMINO_API_PROXY']}{path}",
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def main(dataset_id: str) -> None:
    paths = [f"{domain}.sas7bdat" for domain in SDTM_DOMAINS]
    snapshot = _request("POST", f"/api/datasetrw/v1/datasets/{dataset_id}/snapshots", {"relativeFilePaths": paths})["snapshot"]
    print(f"Created snapshot {snapshot['id']} of dataset {dataset_id} ({snapshot['status']})")

    deadline = time.monotonic() + TIMEOUT_S
    while snapshot["status"] != "active":
        if snapshot["status"] in TERMINAL_FAILURE_STATUSES:
            sys.exit(f"Snapshot {snapshot['id']} ended in status {snapshot['status']}")
        if time.monotonic() > deadline:
            sys.exit(f"Snapshot {snapshot['id']} still {snapshot['status']} after {TIMEOUT_S}s")
        time.sleep(POLL_INTERVAL_S)
        snapshot = _request("GET", f"/api/datasetrw/v1/snapshots/{snapshot['id']}")["snapshot"]
    print(f"Snapshot {snapshot['id']} is active")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: python scripts/snapshot_sdtm_dataset.py <dataset_id>\n")
        sys.exit(1)
    main(sys.argv[1])
