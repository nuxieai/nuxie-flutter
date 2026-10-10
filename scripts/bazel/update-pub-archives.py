#!/usr/bin/env python3
"""Record the hosted archive identities resolved by the owning Flutter lockfiles."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
PACKAGES = ('nuxie_flutter_platform_interface', 'nuxie_flutter_native', 'nuxie_flutter',
            'nuxie_flutter_bloc', 'nuxie_flutter_riverpod', 'nuxie_flutter/example')


def archive_pins(lock, report):
    entries = {}
    for match in re.finditer(r'^  ([a-zA-Z0-9_]+):\n(.*?)(?=^  [a-zA-Z0-9_]+:|^sdks:|\Z)', lock, re.M | re.S):
        name, body = match.groups()
        fields = {key: re.search(r'^\s+' + key + r':\s*["\']?([^\n"\']+)', body, re.M)
                  for key in ('source', 'version', 'sha256', 'url')}
        if fields['source'] and fields['source'].group(1).strip() == 'hosted':
            if any(not fields[key] for key in ('version', 'sha256', 'url')):
                raise ValueError('Hosted lock entry lacks its archive identity: ' + name)
            version, digest, url = [fields[key].group(1).strip() for key in ('version', 'sha256', 'url')]
            if url != 'https://pub.dev' or not re.fullmatch(r'[0-9a-f]{64}', digest):
                raise ValueError('Unsupported hosted archive identity: ' + name)
            entries[name] = {'version': version, 'sha256': digest}
    selected = {item['name']: item['version'] for item in report['packages'] if item['source'] == 'hosted'}
    if set(selected) != set(entries) or any(entries[name]['version'] != version for name, version in selected.items()):
        raise ValueError('pub_deps.json and the owning pubspec.lock resolve different hosted dependencies')
    return entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    selected = {}
    for package in PACKAGES:
        directory = ROOT / 'packages' / package
        pins = archive_pins((directory / 'pubspec.lock').read_text(), json.loads((directory / 'pub_deps.json').read_text()))
        for name, pin in pins.items():
            if name in selected and selected[name] != pin:
                raise ValueError('Flutter packages resolve conflicting hosted archives: ' + name)
            selected[name] = pin
    value = json.dumps(dict(sorted(selected.items())), indent=2) + '\n'
    target = ROOT / 'scripts/bazel/pub-archives.json'
    if args.check:
        if target.read_text() != value:
            raise ValueError('Regenerate scripts/bazel/pub-archives.json from the owning Flutter lockfiles')
    else:
        target.write_text(value)


if __name__ == '__main__':
    main()
