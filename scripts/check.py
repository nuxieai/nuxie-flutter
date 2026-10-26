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


def pool_cli():
    """Use the declared Flutter version in a writable, request-owned SDK copy."""
    if os.environ.get('_NUXIE_SDK_SNAPSHOT') != '1': return
    launcher = str(ROOT / 'scripts/bazel/bazel.sh')
    execution = Path(subprocess.check_output([launcher, 'info', 'execution_root'], cwd=ROOT, text=True).strip())
    files = subprocess.check_output([launcher, 'cquery', '@flutter_sdk//:flutter', '--output=files'], cwd=ROOT, text=True).splitlines()
    if len(files) != 1: raise ValueError('Expected the declared host Flutter launcher')
    binary = Path(files[0])
    if not binary.is_absolute(): binary = execution / binary
    sdk = binary.resolve(strict=True).parents[1]
    destination = ROOT / '.nuxie/flutter-cli'
    shutil.copytree(sdk, destination, symlinks=True)
    for path in [destination, *destination.rglob('*')]:
        if not path.is_symlink(): path.chmod(path.stat().st_mode | 0o200)
    os.environ['PATH'] = str(destination / 'bin') + os.pathsep + os.environ['PATH']
    os.environ['CI'] = 'true'
    os.environ['FLUTTER_SUPPRESS_ANALYTICS'] = 'true'


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
    pool_cli()
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
        isolated = ['-derivedDataPath', str(ROOT / '.nuxie/ios-derived-data')] if os.environ.get('_NUXIE_SDK_SNAPSHOT') == '1' else []
        run(['xcodebuild', *isolated, '-jobs', workers, '-workspace', 'Runner.xcworkspace', '-scheme', 'Runner',
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
    selected = parser.parse_args().platform
    from pool import dispatch
    status = dispatch('check', ['--platform', selected])
    if status is not None: raise SystemExit(status)
    check(selected)


if __name__ == '__main__':
    main()
