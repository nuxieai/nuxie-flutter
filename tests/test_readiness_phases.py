import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('flutter_readiness',ROOT/'scripts/check.py')
check=importlib.util.module_from_spec(spec);spec.loader.exec_module(check)

class ReadinessPhaseTests(unittest.TestCase):
    def execute(self,selected,phase=True):
        calls=[]
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            fixtures=root/'packages/nuxie_flutter_native/test/fixtures';fixtures.mkdir(parents=True)
            (fixtures/'PROVENANCE.json').write_text('{"files":[]}')
            android=root/'packages/nuxie_flutter/example/android';(android/'gradle/wrapper').mkdir(parents=True)
            for name in ('gradlew','gradlew.bat','gradle/wrapper/gradle-wrapper.jar'):(android/name).touch()
            with patch.object(check,'ROOT',root),patch.object(check,'pool_cli'),patch.object(check,'run',side_effect=lambda args,*a,**k:calls.append(args)),patch.object(check.sys,'platform','darwin'),patch.object(check.platform,'machine',return_value='arm64'),patch.object(check.subprocess,'check_output',return_value=json.dumps({'flutterRoot':str(root)})):
                check.check(selected,phase=phase)
        return calls

    def test_android_phase_runs_only_native_consumer_work(self):
        calls=self.execute('android')
        self.assertTrue(any('build-native' in c and 'android' in c for c in calls))
        self.assertTrue(any(c[0]=='./gradlew' for c in calls))
        self.assertFalse(any('check' in c or 'pigeon' in c or c[0]=='xcodebuild' for c in calls))

    def test_ios_phase_keeps_the_simulator_consumer_without_portable_reruns(self):
        calls=self.execute('ios')
        self.assertTrue(any(c[0]=='xcodebuild' for c in calls))
        self.assertFalse(any('check' in c or 'pigeon' in c or c[0]=='./gradlew' for c in calls))

    def test_portable_oracles_remain_in_public_platform_checks(self):
        calls=self.execute('android',phase=False)
        self.assertTrue(any('check' in c for c in calls))
        self.assertTrue(any('pigeon' in c for c in calls))
