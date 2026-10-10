#!/usr/bin/env python3
"""Local and CI entrypoint for pinned Flutter package graphs."""
import argparse
import os
import platform
import sys
from pathlib import Path
import subprocess

sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_prepare import prepare

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / 'scripts/bazel/bazel.sh'


def non_android_environment():
    # Dart and Apple targets use rules_android's empty SDK repository.
    return dict(os.environ, ANDROID_HOME='', ANDROID_SDK_ROOT='')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['build', 'test', 'analyze', 'check', 'build-native'])
    args = parser.parse_args()
    if args.command == 'build-native':
        products = prepare(ROOT, ['ios', 'android'])
        environment = dict(non_android_environment(), NUXIE_IOS_ARTIFACTS=str(products['ios']),
                           NUXIE_ANDROID_ARTIFACTS=str(products['android']))
        architecture = platform.machine()
        subprocess.run([str(LAUNCHER), 'build', '//packages/nuxie_flutter_native/ios:bridge',
                        '--platforms=//:ios_simulator_' + architecture, '--ios_minimum_os=15.0'],
                       cwd=ROOT, env=environment, check=True)
        environment.update({key: os.environ.get(key, '') for key in ('ANDROID_HOME', 'ANDROID_SDK_ROOT')})
        subprocess.run([str(LAUNCHER), 'build', '//packages/nuxie_flutter_native/android:bridge', '--platforms=//:android_arm64', '--extra_toolchains=@androidsdk//:sdk-toolchain'],
                       cwd=ROOT, env=environment, check=True)
        return
    targets = {'build': ['build', '//:sdk'], 'test': ['test', '//:unit_tests'],
               'analyze': ['test', '//:analysis'], 'check': ['test', '//:unit_tests', '//:analysis']}
    subprocess.run([str(LAUNCHER), *targets[args.command]], cwd=ROOT, env=non_android_environment(), check=True)


if __name__ == '__main__':
    main()
