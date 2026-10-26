#!/usr/bin/env python3
"""Acquire pinned native sources and prepare their Bazel product contracts."""
import argparse
from pathlib import Path
import sys

from pool import dispatch
status = dispatch('prepare-native', sys.argv[1:])
if status is not None: raise SystemExit(status)

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'scripts/bazel'))
from native_prepare import prepare

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--platform', choices=['android', 'ios', 'all'], default='all')
parser.add_argument('--configuration', choices=['Debug', 'Release'], default='Debug')
args = parser.parse_args()
prepare(root, ['ios', 'android'] if args.platform == 'all' else [args.platform], args.configuration)
print('Native Bazel products ready in this checkout; source consumers retain their recorded pins.')
