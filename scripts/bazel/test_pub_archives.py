"""Independent lockfile/report consistency checks for hosted archive identity."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('pub_archives', Path(__file__).with_name('update-pub-archives.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

LOCK = '''packages:
  collection:
    description:
      name: collection
      sha256: "1111111111111111111111111111111111111111111111111111111111111111"
      url: "https://pub.dev"
    source: hosted
    version: "1.19.1"
  flutter:
    description: flutter
    source: sdk
    version: "0.0.0"
sdks:
  dart: ">=3.10.0 <4.0.0"
'''
REPORT = {'packages': [{'name': 'collection', 'version': '1.19.1', 'source': 'hosted'},
                       {'name': 'flutter', 'version': '0.0.0', 'source': 'sdk'}]}


class PubArchivesTests(unittest.TestCase):
    def test_owning_lock_selects_only_exact_hosted_archive(self):
        self.assertEqual(module.archive_pins(LOCK, REPORT),
                         {'collection': {'version': '1.19.1', 'sha256': '1' * 64}})

    def test_report_version_drift_is_rejected(self):
        report = {'packages': [{'name': 'collection', 'version': '2.0.0', 'source': 'hosted'}]}
        with self.assertRaisesRegex(ValueError, 'different hosted'):
            module.archive_pins(LOCK, report)

    def test_missing_or_corrupt_archive_identity_is_rejected(self):
        for value in (LOCK.replace('1' * 64, 'missing'), LOCK.replace('https://pub.dev', 'https://example.org')):
            with self.assertRaisesRegex(ValueError, 'Unsupported hosted'):
                module.archive_pins(value, REPORT)

    def test_missing_report_dependency_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'different hosted'):
            module.archive_pins(LOCK, {'packages': []})


if __name__ == '__main__':
    unittest.main()
