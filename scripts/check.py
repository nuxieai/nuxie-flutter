#!/usr/bin/env python3
"""Readiness checks, with explicit portable, Android and iOS execution seams."""
import argparse
import hashlib
import json
import os
import platform
import re
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def run(args, cwd=ROOT, env=None):
    print('+ ' + ' '.join(args), flush=True)
    subprocess.run(args, cwd=cwd, env=env, check=True)


def check(selected='all'):
    if selected not in ('portable', 'android', 'ios', 'all'):
        raise ValueError('Select portable, android, ios or all')
    ios = selected in ('ios', 'all')
    android = selected in ('android', 'all')
    if ios and sys.platform != 'darwin':
        raise ValueError('iOS Flutter readiness requires macOS for the simulator build')
    # These portable checks remain in full readiness and every platform lane.
    # They validate fixture provenance, Dart contracts and generated interfaces.
    fixtures = ROOT / 'packages/nuxie_flutter_native/test/fixtures'
    for entry in json.loads((fixtures / 'PROVENANCE.json').read_text())['files']:
        if hashlib.sha256((fixtures / entry['file']).read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError('Fixture hash mismatch: ' + entry['file'])
    run([sys.executable, 'scripts/bazel/sdk.py', 'check'])
    native = ROOT / 'packages/nuxie_flutter_native'
    run(['flutter', 'pub', 'get'], native)
    run(['dart', 'run', 'pigeon', '--input', 'pigeons/nuxie_bridge.dart'], native)
    run(['git', 'diff', '--exit-code', '--',
         'packages/nuxie_flutter_native/lib/src/generated',
         'packages/nuxie_flutter_native/android/src/main/kotlin/io/nuxie/flutter/nativeplugin/NuxieBridge.g.kt',
         'packages/nuxie_flutter_native/ios/nuxie_flutter_native/Sources/nuxie_flutter_native/NuxieBridge.g.swift'])
    if selected == 'portable':
        return
    # build-native owns one preparation of exactly the selected platforms.
    run([sys.executable, 'scripts/bazel/sdk.py', 'build-native', '--platform', selected])
    example = ROOT / 'packages/nuxie_flutter/example'
    env = dict(os.environ)
    for key in ('NUXIE_IOS_SDK_PATH', 'NUXIE_RUNTIME_USE_LOCAL', 'NUXIE_ANDROID_SDK_PATH'):
        env.pop(key, None)
    run(['flutter', 'pub', 'get'], example, env)
    if ios:
        run(['flutter', 'build', 'ios', '--simulator', '--debug', '--config-only'], example, env)
        simulator_arch = platform.machine()
        if simulator_arch not in ('arm64', 'x86_64'):
            raise ValueError('Unsupported simulator host architecture: ' + simulator_arch)
        workers = env.get('NUXIE_BAZEL_CPU', '2')
        if not re.fullmatch(r'[1-9][0-9]*', workers):
            raise ValueError('iOS workers must be a positive integer')
        run(['xcodebuild', '-jobs', workers, '-workspace', 'Runner.xcworkspace', '-scheme', 'Runner',
             '-configuration', 'Debug', '-sdk', 'iphonesimulator', '-destination', 'generic/platform=iOS Simulator',
             'ARCHS=' + simulator_arch, 'CODE_SIGNING_ALLOWED=NO', 'build'], example / 'ios', env)
    if android:
        # Direct Gradle compiles the real Dart/plugin consumer using JAVA_HOME.
        flutter = json.loads(subprocess.check_output(['flutter', '--version', '--machine'], text=True))
        wrapper = Path(flutter['flutterRoot']) / 'bin/cache/artifacts/gradle_wrapper'
        for relative in ('gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar'):
            target = example / 'android' / relative
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(wrapper / relative, target)
        (example / 'android/gradlew').chmod(0o755)
        run(['./gradlew', '--no-daemon', '--max-workers=' + ('1' if os.environ.get('NUXIE_CI_RUNNER_POLICY_VERSION') == '2' else '2'), ':app:assembleDebug'], example / 'android', env)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['portable', 'android', 'ios', 'all'], default='all')
    check(parser.parse_args().platform)


if __name__ == '__main__':
    main()
