import 'dart:async';
import 'validation.dart';
import 'package:flutter/material.dart';
import 'package:nuxie_flutter/nuxie_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NuxieExample(client: Nuxie.instance));
}

/// The same app and API exercise run on iOS and Android.
class NuxieExample extends StatelessWidget {
  const NuxieExample({super.key, required this.client});
  final NuxieClient client;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nuxie SDK Lab',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.deepPurple,
    ),
    home: SdkLab(client: client),
  );
}

class SdkLab extends StatefulWidget {
  const SdkLab({super.key, required this.client});
  final NuxieClient client;
  @override
  State<SdkLab> createState() => _SdkLabState();
}

class _SdkLabState extends State<SdkLab> {
  final iosKey = TextEditingController(
    text: const String.fromEnvironment('NUXIE_IOS_API_KEY'),
  );
  final androidKey = TextEditingController(
    text: const String.fromEnvironment('NUXIE_ANDROID_API_KEY'),
  );
  final user = TextEditingController(text: 'flutter-sdk-lab');
  final event = TextEditingController(
    text: const String.fromEnvironment(
      'NUXIE_EVENT',
      defaultValue: 'sdk_lab_opened',
    ),
  );
  final feature = TextEditingController(
    text: const String.fromEnvironment(
      'NUXIE_FEATURE',
      defaultValue: 'exports',
    ),
  );
  final amount = TextEditingController(text: '1');
  final entity = TextEditingController();
  final locale = TextEditingController();
  final List<String> log = [];
  final List<StreamSubscription<dynamic>> subscriptions = [];
  bool busy = false;
  String? identity;
  int page = 0;
  NuxieClient get nuxie => widget.client;

  @override
  void initState() {
    super.initState();
    // These listeners exist before configure, including startup delivery.
    subscriptions.add(
      nuxie.activities.listen((value) {
        record('${value.name} · ${value.id}\n${value.properties}');
      }, onError: (Object error) => record('Activity error: $error')),
    );
    subscriptions.add(
      nuxie.appActions.listen((value) {
        record('App Action: ${value.name}\n${value.payload ?? {}}');
        if (value.name == 'open_library' && mounted) {
          setState(() => page = 1);
        }
      }, onError: (Object error) => record('App Action error: $error')),
    );
    if (const bool.fromEnvironment('NUXIE_VALIDATE')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(run('Validation', validate));
      });
    } else if (const bool.fromEnvironment('NUXIE_AUTOCONNECT')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(run('Configure', configure));
      });
    }
  }

  void record(String value) {
    debugPrint('SDK_LAB: $value');
    if (!mounted) return;
    setState(() {
      log.insert(0, '${DateTime.now().toLocal().toIso8601String()}\n$value');
      if (log.length > 100) log.removeLast();
    });
  }

  Future<void> run(String label, Future<Object?> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await operation();
      record('$label ✓${result == null ? '' : '\n$result'}');
    } catch (error) {
      record('$label failed\n$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> configure() async {
    await nuxie.configure(
      NuxieConfiguration(
        apiKeys: NuxieApiKeys(
          ios: iosKey.text.trim(),
          android: androidKey.text.trim(),
        ),
        environment: NuxieEnvironment.development,
      ),
    );
    identity = await nuxie.getDistinctId();
  }

  Future<void> validate() => validateSdk(
    nuxie,
    NuxieConfiguration(
      apiKeys: NuxieApiKeys(
        ios: iosKey.text.trim(),
        android: androidKey.text.trim(),
      ),
      environment: NuxieEnvironment.development,
    ),
    record,
    event: event.text.trim(),
    featureId: feature.text.trim(),
    customerId: const String.fromEnvironment('NUXIE_CUSTOMER').isEmpty
        ? null
        : const String.fromEnvironment('NUXIE_CUSTOMER'),
    entityA: const String.fromEnvironment('NUXIE_ENTITY_A').isEmpty
        ? null
        : const String.fromEnvironment('NUXIE_ENTITY_A'),
    entityB: const String.fromEnvironment('NUXIE_ENTITY_B').isEmpty
        ? null
        : const String.fromEnvironment('NUXIE_ENTITY_B'),
    expectedAppAction:
        const String.fromEnvironment('NUXIE_VALIDATE_APP_ACTION').isEmpty
        ? null
        : const String.fromEnvironment('NUXIE_VALIDATE_APP_ACTION'),
  );

  Widget input(
    String label,
    TextEditingController controller, {
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget action(
    String title,
    Future<Object?> Function() call, {
    bool needsSetup = true,
  }) => OutlinedButton(
    onPressed: busy || (needsSetup && !nuxie.isConfigured)
        ? null
        : () => run(title, call),
    child: Text(title),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Nuxie SDK Lab'),
      actions: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Chip(
            label: Text(nuxie.isConfigured ? 'Connected' : 'Not configured'),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            [
              'Connect your app',
              'Features & usage',
              'Events & callbacks',
            ][page],
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Development environment · ${Theme.of(context).platform.name}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 20),
          if (page == 0) ...[
            const Text(
              'Use your development app’s public keys. Purchases and presentation are handled by the native SDK.',
            ),
            const SizedBox(height: 16),
            input('iOS public API key', iosKey),
            input('Android public API key', androidKey),
            FilledButton(
              onPressed: busy ? null : () => run('Configure', configure),
              child: const Text('Configure'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => run('Validation', validate),
              child: const Text('Validate with a disposable customer'),
            ),
            const SizedBox(height: 16),
            SelectableText(
              'Wrapper ${nuxie.versions.wrapper}\nNative ${nuxie.versions.native ?? '—'}\nContract ${nuxie.versions.contract ?? '—'}\nIdentity ${identity ?? '—'}',
            ),
            const Divider(height: 32),
            input('Customer ID', user),
            Wrap(
              spacing: 8,
              children: [
                action('Identify', () async {
                  await nuxie.identify(
                    user.text,
                    userProperties: {'integration': 'flutter'},
                  );
                  identity = await nuxie.getDistinctId();
                  return identity;
                }),
                action('Read identity', () async {
                  identity = await nuxie.getDistinctId();
                  return 'distinct: $identity\nanonymous: ${await nuxie.getAnonymousId()}\nidentified: ${await nuxie.getIsIdentified()}';
                }),
                action('Reset user', () async {
                  await nuxie.reset();
                  identity = await nuxie.getDistinctId();
                  return identity;
                }),
              ],
            ),
            input(
              'Locale override',
              locale,
              hint: 'Empty follows the device locale',
            ),
            action(
              'Set locale',
              () => nuxie.setLocaleIdentifier(
                locale.text.isEmpty ? null : locale.text,
              ),
            ),
            action('Restore purchases', () async {
              final result = await nuxie.restorePurchases();
              return '${result.type.name}${result.message == null ? '' : ': ${result.message}'}';
            }),
            action('Shutdown', () async {
              await nuxie.shutdown();
              identity = null;
              return null;
            }),
          ],
          if (page == 1) ...[
            ValueListenableBuilder<NuxieFeatureSnapshot>(
              valueListenable: nuxie.features,
              builder: (context, snapshot, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Native state: ${snapshot.state.name}'),
                      if (snapshot.all.isEmpty)
                        const Text('No Features in the current snapshot.'),
                      for (final entry in snapshot.all.entries)
                        Text(
                          '${entry.key}: ${entry.value.allowed ? 'allowed' : 'denied'} · ${entry.value.unlimited ? 'unlimited' : entry.value.balance ?? 'no balance'}',
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            input('Feature ID', feature),
            input('Amount / required balance', amount),
            input(
              'Entity ID',
              entity,
              hint: 'Optional; scoped checks never use global snapshot deltas',
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final policy in FeatureCheckPolicy.values)
                  action('Check ${policy.name}', () async {
                    final value = await nuxie.hasFeature(
                      feature.text,
                      requiredBalance: double.parse(amount.text),
                      entityId: entity.text.isEmpty ? null : entity.text,
                      policy: policy,
                    );
                    return 'allowed=${value.allowed}, unlimited=${value.unlimited}, balance=${value.balance}';
                  }),
                action('Consume & wait', () async {
                  final result = await nuxie.useFeatureAndWait(
                    feature.text,
                    amount: double.parse(amount.text),
                    entityId: entity.text.isEmpty ? null : entity.text,
                    metadata: {'source': 'flutter_sdk_lab'},
                  );
                  return 'committed=${result.success}, used=${result.amountUsed}, remaining=${result.usage?.remaining}, authoritative=${result.authoritativeAccess?.allowed}\n${result.message ?? ''}';
                }),
                action(
                  'Report usage',
                  () => nuxie.useFeature(
                    feature.text,
                    amount: double.parse(amount.text),
                    entityId: entity.text.isEmpty ? null : entity.text,
                  ),
                ),
              ],
            ),
            const Text(
              'Usage spends positive whole credits. An entity can spend only its assigned grants. A final-credit command can succeed with no credits remaining.',
            ),
          ],
          if (page == 2) ...[
            input('Trigger event', event),
            const Text(
              'Use an event authored as a Journey entry condition to test native presentation. An App Action named open_library selects the Features tab.',
            ),
            Wrap(
              spacing: 8,
              children: [
                action(
                  'Trigger event',
                  () => nuxie.trigger(
                    event.text,
                    properties: {'source': 'flutter_sdk_lab'},
                  ),
                ),
                action('Dismiss Experience', nuxie.dismiss),
              ],
            ),
          ],
          const Divider(height: 32),
          Text(
            'Activity & results',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (log.isEmpty)
            const Text('Commands and native callbacks will appear here.'),
          for (final line in log.take(20))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectableText(
                line,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (value) => setState(() => page = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.link), label: 'Connect'),
        NavigationDestination(
          icon: Icon(Icons.verified_user_outlined),
          label: 'Features',
        ),
        NavigationDestination(icon: Icon(Icons.bolt), label: 'Events'),
      ],
    ),
  );

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    for (final controller in [
      iosKey,
      androidKey,
      user,
      event,
      feature,
      amount,
      entity,
      locale,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
