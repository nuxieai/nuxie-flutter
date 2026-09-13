# Native version map

The authoritative source pins are in [NATIVE-PINS.json](NATIVE-PINS.json).

| Wrapper | Contract | iOS source | Android source |
| --- | --- | --- | --- |
| 0.2.0 source preview | 2 | `c2f304eb87f3efbedaa38052ca64eab53e0d0b0f` | `1cfd174cc6a713794e93c1654e37bec853f7e38f` |

The iOS Swift package uses the immutable revision directly. Android uses an explicit Gradle composite source build prepared by `python3 scripts/prepare-native.py`; `0.2.0-source` is a substitution coordinate, not a published Maven artifact. Publication remains disabled until normal registry artifacts are qualified. Local environment overrides are for native development and must be recorded when reporting test evidence.
