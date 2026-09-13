# Native version map

The authoritative source pins are in [NATIVE-PINS.json](NATIVE-PINS.json).

| Wrapper | Contract | iOS source | Android source |
| --- | --- | --- | --- |
| 0.2.0 source preview | 2 | `1c6ca493d50b5df477d79ccf734951ed774e78d9` | `4144a858ed93ad757e1db7cb1e3f34ffc7bbd343` |

The iOS Swift package uses the immutable revision directly. Android uses an explicit Gradle composite source build prepared by `python3 scripts/prepare-native.py`; `0.2.0-source` is a substitution coordinate, not a published Maven artifact. Publication remains disabled until normal registry artifacts are qualified. Local environment overrides are for native development and must be recorded when reporting test evidence.
