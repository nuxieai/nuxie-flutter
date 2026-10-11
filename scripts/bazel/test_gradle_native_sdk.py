"""Exercise the Maven consumer with a real Gradle installation, offline."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(os.environ.get("GRADLE_BIN"), "Set GRADLE_BIN to qualify the offline Maven consumer")
class GradleNativeSdkTests(unittest.TestCase):
    def test_kotlin_example_resolves_the_app_project_coordinate(self):
        with tempfile.TemporaryDirectory(prefix="flutter-kotlin-maven-consumer-") as directory:
            project = Path(directory).resolve()
            aar, _, _ = self.product_fixture(project)
            app = project / "packages/nuxie_flutter/example/android/app"
            app.mkdir(parents=True)
            (project / "settings.gradle.kts").write_text(
                'rootProject.name = "native-kotlin-consumer"\n'
                'include(":app")\nproject(":app").projectDir = file("packages/nuxie_flutter/example/android/app")\n'
            )
            # A root property cannot stand in for the coordinate owned by the app.
            (project / "build.gradle.kts").write_text(
                'extra["nuxieAndroidCoordinate"] = "wrong:root-coordinate:0"\n'
            )
            authored = (ROOT / "packages/nuxie_flutter/example/android/app/build.gradle.kts").read_text()
            consumer = authored[authored.index('extra["nuxieFlutterRepoRoot"]'):]
            (app / "build.gradle.kts").write_text(
                'plugins { java }\n' + consumer
                + '\nval nativeSdk = configurations.create("nativeSdk") {\n'
                '    extendsFrom(configurations["implementation"])\n}\n'
                'tasks.register("verifyProduct") { doLast {\n'
                '    check(nativeSdk.singleFile.name == "' + aar.name + '")\n'
                '    println("Resolved app project source-addressed AAR")\n}\n}\n'
            )
            helper = project / "scripts/gradle/native-sdk.gradle"
            helper.parent.mkdir(parents=True)
            helper.write_bytes((ROOT / "scripts/gradle/native-sdk.gradle").read_bytes())
            environment = dict(os.environ)
            environment.pop("NUXIE_ANDROID_ARTIFACTS", None)
            result = subprocess.run(
                [os.environ["GRADLE_BIN"], "--no-daemon", "--offline", "--max-workers=1", ":app:verifyProduct"],
                cwd=project, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("Resolved app project source-addressed AAR", result.stdout)

    def product_fixture(self, project):
        revision = "1" * 40
        version = "0.2.0-" + revision
        (project / "NATIVE-PINS.json").write_text(json.dumps({"android": {"revision": revision}}))
        product = project / ".native/artifacts/android"
        artifacts = product / ("ai/nuxie/nuxie-android/" + version)
        artifacts.mkdir(parents=True)
        stem = "nuxie-android-" + version
        aar = artifacts / (stem + ".aar")
        with zipfile.ZipFile(aar, "w") as archive:
            archive.writestr("AndroidManifest.xml", '<manifest package="fixture.sdk"/>')
        (artifacts / (stem + ".pom")).write_text(
            "<project><modelVersion>4.0.0</modelVersion><groupId>ai.nuxie</groupId>"
            "<artifactId>nuxie-android</artifactId><version>" + version
            + "</version><packaging>aar</packaging></project>"
        )
        (artifacts / (stem + ".module")).write_text(json.dumps({
            "formatVersion": "1.1",
            "component": {"group": "ai.nuxie", "module": "nuxie-android", "version": version},
            "variants": [{"name": "runtime", "files": [{"name": aar.name, "url": aar.name}]}],
        }))
        receipt = {
            "schemaVersion": 1, "sdk": "android", "sourceRevision": revision, "sourceDirty": False,
            "maven": {"groupId": "ai.nuxie", "artifactId": "nuxie-android", "version": version},
            "artifacts": [{"path": path.relative_to(product).as_posix(), "size": path.stat().st_size,
                           "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                          for path in sorted(artifacts.iterdir())],
        }
        manifest = product / "sdk-artifacts.json"
        manifest.write_text(json.dumps(receipt))
        return aar, manifest, receipt

    def test_exact_product_resolves_and_changed_pin_or_bytes_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix="flutter-maven-consumer-") as directory:
            project = Path(directory).resolve()
            aar, manifest, receipt = self.product_fixture(project)
            revision = receipt["sourceRevision"]
            (project / "settings.gradle").write_text("rootProject.name = 'native-product-consumer'\n")
            helper = (ROOT / "scripts/gradle/native-sdk.gradle").as_posix().replace("'", "\\'")
            (project / "build.gradle").write_text(
                "ext.nuxieFlutterRepoRoot = projectDir\napply from: '" + helper + "'\n"
                "configurations { nativeSdk }\ndependencies { nativeSdk nuxieAndroidCoordinate }\n"
                "tasks.register('verifyProduct') { doLast { assert configurations.nativeSdk.singleFile.name == '"
                + aar.name + "'; println 'Resolved exact source-addressed AAR' } }\n"
            )
            environment = dict(os.environ)
            environment.pop("NUXIE_ANDROID_ARTIFACTS", None)
            command = [os.environ["GRADLE_BIN"], "--no-daemon", "--offline", "--max-workers=1", "verifyProduct"]

            def resolve():
                return subprocess.run(command, cwd=project, env=environment, text=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

            result = resolve()
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("Resolved exact source-addressed AAR", result.stdout)
            receipt["sourceRevision"] = "2" * 40
            manifest.write_text(json.dumps(receipt))
            result = resolve()
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("does not match NATIVE-PINS.json", result.stdout)
            receipt["sourceRevision"] = revision
            manifest.write_text(json.dumps(receipt))
            data = bytearray(aar.read_bytes())
            data[0] ^= 1  # Preserve size, so only the independently recorded hash can reject it.
            aar.write_bytes(data)
            result = resolve()
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("artifact checksum changed", result.stdout)


if __name__ == "__main__":
    unittest.main()
