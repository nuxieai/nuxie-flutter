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


def pool_dispatch(args):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from pool import dispatch
    return dispatch('sdk', sys.argv[1:], command=args.command)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['build', 'test', 'analyze', 'check', 'build-native'])
    parser.add_argument('--platform', choices=['portable', 'android', 'ios', 'all'], default='all')
    args = parser.parse_args()
    status = pool_dispatch(args)
    if status is not None:
        raise SystemExit(status)
    if args.command != 'build-native' and args.platform != 'all':
        parser.error('--platform selects build-native only')
    if args.command == 'build-native':
        selected = ['ios', 'android'] if args.platform == 'all' else [] if args.platform == 'portable' else [args.platform]
        if not selected:
            return
        if 'ios' in selected and (sys.platform != 'darwin' or platform.machine() not in ('arm64', 'x86_64')):
            raise ValueError('iOS native bridge requires macOS arm64 or x86_64')
        products = prepare(ROOT, selected)
        environment = non_android_environment()
        for key in tuple(environment):
            if (key.startswith('NUXIE_IOS_') and 'ios' not in selected) or (key.startswith('NUXIE_ANDROID_') and 'android' not in selected):
                environment.pop(key)
        for sdk, manifest in products.items():
            environment['NUXIE_' + sdk.upper() + '_ARTIFACTS'] = str(manifest)
        if 'ios' in selected:
            architecture = platform.machine()
            if sys.platform != 'darwin' or architecture not in ('arm64', 'x86_64'):
                raise ValueError('iOS native bridge requires macOS arm64 or x86_64')
            subprocess.run([str(LAUNCHER), 'build', '//packages/nuxie_flutter_native/ios:bridge',
                            '--platforms=//:ios_simulator_' + architecture, '--ios_minimum_os=15.0'],
                           cwd=ROOT, env=environment, check=True)
        if 'android' in selected:
            environment.update({key: os.environ.get(key, '') for key in ('ANDROID_HOME', 'ANDROID_SDK_ROOT')})
            subprocess.run([str(LAUNCHER), 'build', '//packages/nuxie_flutter_native/android:bridge', '--platforms=//:android_arm64',
                            '--extra_toolchains=@androidsdk//:sdk-toolchain'], cwd=ROOT, env=environment, check=True)
        return
    targets = {'build': ['build', '//:sdk'], 'test': ['test', '//:unit_tests'],
               'analyze': ['test', '//:analysis'], 'check': ['test', '//:unit_tests', '//:analysis']}
    subprocess.run([str(LAUNCHER), *targets[args.command]], cwd=ROOT, env=non_android_environment(), check=True)


if __name__ == '__main__':
    main()
