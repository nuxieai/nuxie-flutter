import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuxie_flutter/nuxie_flutter.dart';
import 'package:nuxie_flutter_platform_interface/nuxie_flutter_platform_interface.dart';

const configuration = NuxieConfiguration(
  apiKeys: NuxieApiKeys(ios: 'ios', android: 'android'),
);

class FakePlatform extends NuxieFlutterPlatform {
  final snapshots = StreamController<NativeFeatureSnapshot>.broadcast(
    sync: true,
  );
  final activity = StreamController<NuxieActivityInfo>.broadcast(sync: true);
  final actions = StreamController<NuxieAppAction>.broadcast(sync: true);
  final purchases = StreamController<NuxiePurchaseRequest>.broadcast(
    sync: true,
  );
  final restores = StreamController<NuxieRestoreRequest>.broadcast(sync: true);
  final completion = Completer<void>();
  int setupCount = 0;
  int shutdownCount = 0;
  int contract = 2;
  int uses = 0;
  String session = '';
  PurchaseResult? purchaseResult;
  bool failSetup = false;
  @override
  Stream<NativeFeatureSnapshot> get featureSnapshots => snapshots.stream;
  @override
  Stream<NuxieActivityInfo> get activities => activity.stream;
  @override
  Stream<NuxieAppAction> get appActions => actions.stream;
  @override
  Stream<NuxiePurchaseRequest> get purchaseRequests => purchases.stream;
  @override
  Stream<NuxieRestoreRequest> get restoreRequests => restores.stream;
  @override
  Future<NuxieVersions> configure({
    required String apiKey,
    required String session,
    required NuxieConfiguration options,
    required bool usingPurchaseController,
    required String wrapperVersion,
  }) async {
    this.session = session;
    setupCount++;
    if (failSetup) throw StateError('setup failed');
    activity.add(
      NuxieActivityInfo(
        schemaVersion: 1,
        id: 'startup',
        timestampMs: 1,
        receivedAtMs: 2,
        name: 'app_opened',
        properties: {},
      ),
    );
    if (usingPurchaseController) {
      purchases.add(
        const NuxiePurchaseRequest(
          requestId: 'purchase',
          platform: 'ios',
          productId: 'pro',
          storeProductId: 'pro.monthly',
          timestampMs: 1,
        ),
      );
      await completion.future;
    }
    return NuxieVersions(
      wrapper: wrapperVersion,
      native: 'fixture',
      contract: contract,
    );
  }

  void emit(
    int revision,
    int generation, {
    String? session,
    double balance = 0.5,
  }) => snapshots.add(
    NativeFeatureSnapshot(
      session: session ?? this.session,
      identityGeneration: generation,
      revision: revision,
      value: NuxieFeatureSnapshot(
        state: FeatureState.ready,
        all: {
          'credits': FeatureAccess(
            allowed: true,
            unlimited: false,
            balance: balance,
            type: FeatureType.creditSystem,
          ),
        },
      ),
    ),
  );
  @override
  Future<void> completePurchase(String requestId, PurchaseResult result) async {
    purchaseResult = result;
    completion.complete();
  }

  @override
  Future<void> shutdown() async {
    shutdownCount++;
  }

  @override
  Future<FeatureUsageResult> useFeatureAndWait(
    String featureId, {
    double amount = 1,
    String? entityId,
    bool setUsage = false,
    Map<String, Object?>? metadata,
  }) async {
    uses++;
    return FeatureUsageResult(
      success: true,
      featureId: featureId,
      amountUsed: amount,
      authoritativeAccess: const FeatureAccess(
        allowed: false,
        unlimited: false,
        balance: 0,
        type: FeatureType.creditSystem,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class Controller implements NuxiePurchaseController {
  @override
  Future<PurchaseResult> purchase(NuxieStoreProduct product) async {
    expect(product.storeProductId, 'pro.monthly');
    return const PurchaseResult.purchased();
  }

  @override
  Future<RestoreResult> restorePurchases() async =>
      const RestoreResult.noPurchases();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePlatform platform;
  final client = Nuxie.instance;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    platform = FakePlatform();
    NuxieFlutterPlatform.instance = platform;
  });
  tearDown(() async {
    await client.shutdown();
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'startup delivery and concurrent configure share one connection',
    () async {
      final events = <String>[];
      final subscription = client.activities.listen(
        (event) => events.add(event.id),
      );
      await Future.wait([
        client.configure(configuration),
        client.configure(configuration),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(platform.setupCount, 1);
      expect(events, ['startup']);
      await subscription.cancel();
    },
  );
  test('incompatible contract rolls back native setup before retry', () async {
    platform.contract = 99;
    await expectLater(
      client.configure(configuration),
      throwsA(isA<NuxieException>()),
    );
    expect(client.isConfigured, isFalse);
    expect(platform.shutdownCount, 1);
    platform.contract = 2;
    await client.configure(configuration);
    expect(client.isConfigured, isTrue);
  });

  test('purchase controller is active before native setup completes', () async {
    await client.configure(
      NuxieConfiguration(
        apiKeys: configuration.apiKeys,
        billing: NuxieBilling.external(Controller()),
      ),
    );
    expect(platform.purchaseResult?.type, PurchaseResultType.purchased);
  });
  test('a different configuration fails without changing ownership', () async {
    await client.configure(configuration);
    await expectLater(
      client.configure(
        const NuxieConfiguration(
          apiKeys: NuxieApiKeys(ios: 'different', android: 'android'),
        ),
      ),
      throwsA(isA<NuxieException>()),
    );
    expect(platform.setupCount, 1);
  });
  test('failed setup can be retried explicitly', () async {
    platform.failSetup = true;
    await expectLater(client.configure(configuration), throwsStateError);
    platform.failSetup = false;
    await client.configure(configuration);
    expect(client.isConfigured, true);
    expect(platform.setupCount, 2);
  });
  test('old session, identity and revision cannot overwrite access', () async {
    await client.configure(configuration);
    platform.emit(3, 2);
    platform.emit(2, 2, balance: 8);
    platform.emit(4, 1, balance: 9);
    platform.emit(5, 3, session: 'dead', balance: 10);
    expect(client.features.value['credits']?.balance, 0.5);
    await client.shutdown();
    expect(client.features.value.state, FeatureState.unknown);
    await client.configure(configuration);
    platform.emit(1, 0, balance: 1.5);
    expect(client.features.value['credits']?.balance, 1.5);
  });
  test(
    'spending the last unit succeeds without repeating consumption',
    () async {
      await client.configure(configuration);
      final result = await client.useFeatureAndWait('credits', amount: 0.5);
      expect(result.success, true);
      expect(result.authoritativeAccess?.allowed, false);
      expect(platform.uses, 1);
    },
  );
  test('rejects reserved events, nonfinite amounts and cyclic input', () async {
    await client.configure(configuration);
    await expectLater(client.trigger(r'$identify'), throwsArgumentError);
    await expectLater(
      client.useFeatureAndWait('credits', amount: double.nan),
      throwsArgumentError,
    );
    final cyclic = <String, Object?>{};
    cyclic['self'] = cyclic;
    await expectLater(
      client.identify('customer', userProperties: cyclic),
      throwsArgumentError,
    );
    expect(platform.uses, 0);
  });
}
