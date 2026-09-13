# Troubleshooting

| Symptom | Check |
| --- | --- |
| iOS cannot resolve Nuxie | Enable SwiftPM, use iOS 15+, and follow source-preview native setup. There is no CocoaPod for this plugin. |
| Android native dependency is missing | Use the matching local source substitution for this preview; an old cached 0.1 artifact is incompatible. |
| Configuration reports incompatibleNativeContract | Native bridge contract must be 2. Clean/rebuild the installed app with matching generated code and native sources. |
| alreadyConfigured | Configuration is immutable. Reuse the same configuration, or await explicit shutdown before changing it. |
| engine ownership error | Use the main Flutter engine. A second engine cannot own the process SDK simultaneously. |
| No Experience after trigger | Check public key, environment, published Journey, event name, entry conditions, and native activity. Trigger completion does not prove presentation. |
| Features remain unknown | Inspect native network/authentication logs. Unknown is not denial. Confirm the backend has admitted a profile for the current customer. |
| Empty ready Feature map | Valid state: the customer has no global Feature entries. Query the intended Feature and scope explicitly. |
| Entity query differs from widget | Widgets observe global state. Entity-scoped query results belong to the caller. |
| Usage result is ambiguous | Do not issue a second usage command automatically. Native recovery owns the original durable command. |
| Controller request times out | Return a typed result from every controller method within 120 seconds. Preserve exact offer context; unsupported context should fail explicitly. |
| Local Android cannot connect | Emulator loopback is 10.0.2.2. Use the Lab's debug launch extra and a local app public key. |

Include wrapper/native versions, platform, command, and sanitized error code when reporting an issue. Never include server secrets, customer data, or eligibility tokens.
