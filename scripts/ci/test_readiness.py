"""Execute the real Flutter readiness CLI against private command recorders."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ReadinessTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        (self.root / 'scripts/bazel').mkdir(parents=True)
        shutil.copy2(ROOT / 'scripts/check.py', self.root / 'scripts/check.py')
        fixtures = self.root / 'packages/nuxie_flutter_native/test/fixtures'
        fixtures.mkdir(parents=True)
        data = b'original cross-SDK contract fixture'
        (fixtures / 'fixture.json').write_bytes(data)
        (fixtures / 'PROVENANCE.json').write_text(json.dumps({'files': [{'file': 'fixture.json', 'sha256': hashlib.sha256(data).hexdigest()}]}))
        example = self.root / 'packages/nuxie_flutter/example'
        (example / 'ios').mkdir(parents=True)
        (example / 'android').mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'commands.jsonl'
        script = '#!' + sys.executable + '\n' + '''import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ['COMMAND_LOG'], 'a') as output:
    output.write(json.dumps({'command': name, 'args': sys.argv[1:], 'cwd': os.getcwd()}) + '\\n')
if name == 'flutter' and sys.argv[1:] == ['--version', '--machine']:
    print(json.dumps({'flutterRoot': os.environ['FAKE_FLUTTER_ROOT']}))
'''
        for name in ['flutter', 'dart', 'git', 'xcodebuild']:
            path = self.bin / name
            path.write_text(script)
            path.chmod(0o755)
        (self.root / 'scripts/bazel/sdk.py').write_text(script)
        wrapper = self.root / 'flutter/bin/cache/artifacts/gradle_wrapper'
        (wrapper / 'gradle/wrapper').mkdir(parents=True)
        for name in ['gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar']:
            (wrapper / name).write_text(script)
        self.environment = dict(os.environ, NUXIE_CI_RUNNER_POLICY_VERSION='1', PATH=str(self.bin) + os.pathsep + os.environ['PATH'], COMMAND_LOG=str(self.log), FAKE_FLUTTER_ROOT=str(self.root / 'flutter'))

    def check(self, selected=None):
        argv = [sys.executable, '-B', str(self.root / 'scripts/check.py')]
        if selected is not None:
            argv += ['--platform', selected]
        result = subprocess.run(argv, cwd=self.root, env=self.environment, text=True, capture_output=True, timeout=30)
        commands = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return result, commands

    def test_portable_runs_provenance_dart_and_pigeon_without_native_preparation(self):
        result, commands = self.check('portable')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([item['args'] for item in commands if item['command'] == 'sdk.py'], [['check']])
        self.assertTrue(any(item['args'] == ['run', 'pigeon', '--input', 'pigeons/nuxie_bridge.dart'] for item in commands))
        self.assertTrue(any(item['command'] == 'git' and len(item['args'][3:]) == 3 for item in commands))
        self.assertFalse(any(item['command'] in ['gradlew', 'xcodebuild'] or item['args'][:2] == ['build', 'ios'] for item in commands))

    def test_android_selects_one_native_producer_and_actual_example_without_apple(self):
        result, commands = self.check('android')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([item['args'] for item in commands if item['command'] == 'sdk.py'], [['check'], ['build-native', '--platform', 'android']])
        self.assertEqual([item['args'] for item in commands if item['command'] == 'gradlew'], [['--no-daemon', '--max-workers=2', ':app:assembleDebug']])
        self.assertFalse(any(item['command'] == 'xcodebuild' or item['args'][:2] == ['build', 'ios'] for item in commands))

    def test_v2_android_honors_installed_single_gradle_worker(self):
        self.environment['NUXIE_CI_RUNNER_POLICY_VERSION'] = '2'
        result, commands = self.check('android')
        self.assertEqual(result.returncode, 0, result.stderr)
        gradle = [item for item in commands if item['command'] == 'gradlew']
        self.assertTrue(gradle)
        self.assertTrue(all('--max-workers=1' in item['args'] for item in gradle))

    @unittest.skipUnless(sys.platform == 'darwin', 'iOS consumer fixture requires macOS')
    def test_ios_selects_one_native_producer_and_example_without_android(self):
        result, commands = self.check('ios')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([item['args'] for item in commands if item['command'] == 'sdk.py'], [['check'], ['build-native', '--platform', 'ios']])
        self.assertEqual([item['command'] for item in commands].count('xcodebuild'), 1)
        self.assertFalse(any(item['command'] == 'gradlew' or item['args'] == ['--version', '--machine'] for item in commands))

    @unittest.skipUnless(sys.platform == 'darwin', 'full readiness requires macOS')
    def test_default_full_readiness_preserves_both_native_consumers(self):
        result, commands = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([item['args'] for item in commands if item['command'] == 'sdk.py'], [['check'], ['build-native', '--platform', 'all']])
        self.assertEqual([item['command'] for item in commands].count('xcodebuild'), 1)
        self.assertEqual([item['command'] for item in commands].count('gradlew'), 1)

    def test_changed_provenance_and_invalid_selector_fail_before_commands(self):
        (self.root / 'packages/nuxie_flutter_native/test/fixtures/fixture.json').write_text('changed fixture')
        result, commands = self.check('portable')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, [])
        result, commands = self.check('unknown')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, [])


if __name__ == '__main__':
    unittest.main()
