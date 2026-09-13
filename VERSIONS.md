# Native version map

The authoritative source pins are in [NATIVE-PINS.json](NATIVE-PINS.json).

| Wrapper | Contract | iOS source | Android source |
| --- | --- | --- | --- |
| 0.2.0 source preview | 2 | `0524e1bca5218f879ba37a3dbbffac2fcc74136e` | `784540ac1b39a3e4209361267fb82b3d117091d0` |

The iOS Swift package uses the immutable revision directly. Android uses an explicit Gradle composite source build prepared by `python3 scripts/prepare-native.py`; `0.2.0-source` is a substitution coordinate, not a published Maven artifact. Publication remains disabled until normal registry artifacts are qualified. Local environment overrides are for native development and must be recorded when reporting test evidence.
