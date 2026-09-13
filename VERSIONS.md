# Native version map

The authoritative source pins are in [NATIVE-PINS.json](NATIVE-PINS.json).

| Wrapper | Contract | iOS source | Android source |
| --- | --- | --- | --- |
| 0.2.0 source preview | 2 | `105ec87e2e517b284a44e6e8e65f44fba4ae2ba3` | `51b57ae7a78da66cd88feb0d29c029843a9f1857` |

The iOS Swift package uses the immutable revision directly. Android uses an explicit Gradle composite source build prepared by `python3 scripts/prepare-native.py`; `0.2.0-source` is a substitution coordinate, not a published Maven artifact. Publication remains disabled until normal registry artifacts are qualified. Local environment overrides are for native development and must be recorded when reporting test evidence.
