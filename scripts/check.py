#!/usr/bin/env python3
"""Local source-preview readiness: Dart contracts and both native example builds."""
import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent

def run(args, cwd=root, env=None):
    print('+ ' + ' '.join(args), flush=True)
    subprocess.run(args, cwd=cwd, env=env, check=True)

run([sys.executable, 'scripts/prepare-native.py'])
fixtures = root / 'packages/nuxie_flutter_native/test/fixtures'
for entry in json.loads((fixtures / 'PROVENANCE.json').read_text())['files']:
    if hashlib.sha256((fixtures / entry['file']).read_bytes()).hexdigest() != entry['sha256']:
        raise SystemExit(f"Fixture hash mismatch: {entry['file']}")
for name in ['nuxie_flutter_platform_interface', 'nuxie_flutter_native', 'nuxie_flutter',
             'nuxie_flutter_bloc', 'nuxie_flutter_riverpod', 'nuxie_flutter/example']:
    package = root / 'packages' / name
    run(['flutter', 'pub', 'get'], package)
    run(['flutter', 'analyze'], package)
    run(['flutter', 'test'], package)
native = root / 'packages/nuxie_flutter_native'
run(['dart', 'run', 'pigeon', '--input', 'pigeons/nuxie_bridge.dart'], native)
run(['git', 'diff', '--exit-code', '--',
     'packages/nuxie_flutter_native/lib/src/generated',
     'packages/nuxie_flutter_native/android/src/main/kotlin/io/nuxie/flutter/nativeplugin/NuxieBridge.g.kt',
     'packages/nuxie_flutter_native/ios/nuxie_flutter_native/Sources/nuxie_flutter_native/NuxieBridge.g.swift'])
example = root / 'packages/nuxie_flutter/example'
if sys.platform != 'darwin':
    raise SystemExit('Full Flutter readiness requires macOS for the iOS simulator build.')
run(['flutter', 'build', 'ios', '--simulator', '--debug'], example)
# Direct Gradle avoids Flutter CLI discovery of an unrelated Android Studio JDK.
# The Flutter Gradle plugin still compiles and bundles the actual Dart app.
env = dict(os.environ)
env.pop('NUXIE_ANDROID_SDK_PATH', None)
run(['./gradlew', ':app:assembleDebug'], example / 'android', env)
