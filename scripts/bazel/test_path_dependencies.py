"""Run the pinned rules' embedded Python against isolated package fixtures."""
import ast
import json
import os
from pathlib import Path
import tempfile
import unittest


def relocation_code():
    patch = Path(__file__).with_name("pub-checksums.patch").read_text()
    start = patch.index("+# Nuxie: relocate only declared path dependencies")
    end = patch.index("+# End Nuxie path relocation.", start)
    # The patch adds Python inside a Starlark triple-quoted string. Decode the
    # string once, as Bazel does when generating the actual action/test runner.
    lines = patch[start:end].splitlines()
    embedded = "\n".join(line[1:] for line in lines if line.startswith("+"))
    return ast.literal_eval('"""' + embedded + '"""')


class PathDependencyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.workspace = self.root / "private workspace"
        self.workspace.mkdir()
        self.cache = self.root / "declared cache"
        self.package = self.cache / "hosted/pub.dev/sibling-0.2.0"
        self.package.mkdir(parents=True)
        (self.package / "pubspec.yaml").write_text("name: sibling\nversion: 0.2.0\n")
        self.dependencies = {"packages": [
            {"name": "sibling", "version": "0.2.0", "source": "path"},
            {"name": "hosted", "version": "1.0.0", "source": "hosted"},
        ]}

    def run_relocation(self):
        exec(relocation_code(), {
            "os": os, "data": self.dependencies,
            "cache_root": str(self.cache), "workspace_root": str(self.workspace),
        })

    def test_declared_dependency_points_at_existing_staged_package(self):
        for section in ("dependencies", "dev_dependencies", "dependency_overrides"):
            with self.subTest(section=section):
                original = (f"name: app\n{section}:\n  sibling:\n"
                            "    path: ../sibling\n  unrelated:\n    path: ../untouched\n"
                            "flutter:\n  assets:\n    - images/\n")
                source = self.root / "source-pubspec.yaml"
                source.write_text(original)
                pubspec = self.workspace / "pubspec.yaml"
                pubspec.write_text(original)
                self.run_relocation()
                path_line = next(line for line in pubspec.read_text().splitlines()
                                 if line.startswith("    path: \""))
                dependency_path = json.loads(path_line.split(":", 1)[1])
                self.assertEqual((self.workspace / dependency_path).resolve(), self.package.resolve())
                self.assertFalse(Path(dependency_path).is_absolute())
                self.assertIn("    path: ../untouched\n", pubspec.read_text())
                self.assertTrue(self.package.is_dir())
                self.assertEqual(source.read_text(), original)
                self.assertEqual((self.package / "pubspec.yaml").read_text(),
                                 "name: sibling\nversion: 0.2.0\n")

    def test_missing_declared_package_is_rejected(self):
        (self.workspace / "pubspec.yaml").write_text(
            "dependencies:\n  sibling:\n    path: ../sibling\n")
        self.dependencies["packages"][0]["version"] = "9.0.0"
        with self.assertRaisesRegex(ValueError, "was not staged: sibling"):
            self.run_relocation()

    def test_relocated_workspace_is_reusable_in_another_worktree(self):
        outputs = []
        for name in ("first checkout", "second checkout"):
            workspace = self.root / name / "workspace"
            cache = self.root / name / "cache"
            workspace.mkdir(parents=True)
            (cache / "hosted/pub.dev/sibling-0.2.0").mkdir(parents=True)
            pubspec = workspace / "pubspec.yaml"
            pubspec.write_text("dependencies:\n  sibling:\n    path: ../source\n")
            exec(relocation_code(), {
                "os": os, "data": self.dependencies,
                "cache_root": str(cache), "workspace_root": str(workspace),
            })
            outputs.append(pubspec.read_bytes())
            relative = json.loads(pubspec.read_text().split("path:", 1)[1])
            self.assertTrue((workspace / relative).is_dir())
        self.assertEqual(outputs[0], outputs[1])

    def test_hosted_dependency_does_not_rewrite_a_source_path(self):
        self.dependencies["packages"][0]["source"] = "hosted"
        pubspec = self.workspace / "pubspec.yaml"
        original = "dependencies:\n  sibling:\n    path: ../sibling\n"
        pubspec.write_text(original)
        self.run_relocation()
        self.assertEqual(pubspec.read_text(), original)


if __name__ == "__main__":
    unittest.main()
