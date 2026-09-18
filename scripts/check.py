#!/usr/bin/env python3
"""Local source-preview readiness: Dart contracts and both native example builds."""
import json
import hashlib
import os
import platform
from pathlib import Path
import shutil
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
env = dict(os.environ)
for key in ['NUXIE_IOS_SDK_PATH', 'NUXIE_RUNTIME_USE_LOCAL', 'NUXIE_ANDROID_SDK_PATH']:
    env.pop(key, None)
run(['flutter', 'build', 'ios', '--simulator', '--debug', '--config-only'], example, env)
# Qualify the local simulator architecture explicitly. Xcode 27's lipo rejects
# Flutter's multi-architecture verification even when both slices are present.
simulator_arch = platform.machine()
if simulator_arch not in ('arm64', 'x86_64'):
    raise SystemExit(f'Unsupported simulator host architecture: {simulator_arch}')
run(['xcodebuild', '-workspace', 'Runner.xcworkspace', '-scheme', 'Runner',
     '-configuration', 'Debug', '-sdk', 'iphonesimulator',
     '-destination', 'generic/platform=iOS Simulator',
     f'ARCHS={simulator_arch}', 'CODE_SIGNING_ALLOWED=NO', 'build'], example / 'ios', env)
# Direct Gradle avoids Flutter CLI discovery of an unrelated Android Studio JDK.
# The Flutter Gradle plugin still compiles and bundles the actual Dart app.
flutter = json.loads(subprocess.check_output(['flutter', '--version', '--machine'], text=True))
wrapper = Path(flutter['flutterRoot']) / 'bin/cache/artifacts/gradle_wrapper'
for relative in ['gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar']:
    target = example / 'android' / relative
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(wrapper / relative, target)
(example / 'android/gradlew').chmod(0o755)
run(['./gradlew', ':app:assembleDebug'], example / 'android', env)
