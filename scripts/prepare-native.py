#!/usr/bin/env python3
"""Acquire immutable native SDK sources for the Flutter source preview."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
pins = json.loads((root / "NATIVE-PINS.json").read_text())
for platform in ("ios", "android"):
    pin = pins[platform]
    target = root / ".native" / platform
    target.parent.mkdir(exist_ok=True)
    existed = target.exists()
    if not existed:
        subprocess.run(["git", "clone", "--no-checkout", pin["repository"], str(target)], check=True)
    current = subprocess.run(["git", "status", "--porcelain"], cwd=target, text=True, capture_output=True, check=True).stdout
    # A fresh --no-checkout clone appears deleted until its first checkout.
    if current and existed:
        raise SystemExit(f"Preserving modified native checkout: {target}")
    subprocess.run(["git", "fetch", "origin", pin["revision"]], cwd=target, check=True)
    subprocess.run(["git", "checkout", "--detach", pin["revision"]], cwd=target, check=True)
    actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=target, text=True).strip()
    if actual != pin["revision"]:
        raise SystemExit(f"Native pin mismatch for {platform}")
    print(f"{platform}: {actual}")
print("Native sources ready. The example resolves Android from .native/android; iOS uses its pinned Swift package.")
