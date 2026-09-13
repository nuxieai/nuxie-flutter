import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../models/feature_models.dart';
import '../models/journey_models.dart';
import '../models/nuxie_configuration.dart';
import '../models/purchase_models.dart';

abstract class NuxieFlutterPlatform extends PlatformInterface {
  NuxieFlutterPlatform() : super(token: _token);

  static final Object _token = Object();
  static NuxieFlutterPlatform _instance = _UnsupportedNuxieFlutterPlatform();

  static bool get isRegistered =>
      _instance is! _UnsupportedNuxieFlutterPlatform;

  static NuxieFlutterPlatform get instance => _instance;

  static set instance(NuxieFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<NativeFeatureSnapshot> get featureSnapshots;
  Stream<NuxieActivityInfo> get activities;
  Stream<NuxieAppAction> get appActions;
  Stream<NuxiePurchaseRequest> get purchaseRequests;
  Stream<NuxieRestoreRequest> get restoreRequests;

  Future<NuxieVersions> configure({
    required String session,
    required String apiKey,
    required NuxieConfiguration options,
    required bool usingPurchaseController,
    required String wrapperVersion,
  });

  Future<RestoreResult> restorePurchases();
  Future<void> shutdown();

  Future<void> identify(
    String distinctId, {
    Map<String, Object?>? userProperties,
    Map<String, Object?>? userPropertiesSetOnce,
  });

  Future<void> reset({bool keepAnonymousId = false});
  Future<String> getDistinctId();
  Future<String> getAnonymousId();
  Future<bool> getIsIdentified();

  Future<void> trigger(String event, {Map<String, Object?>? properties});

  Future<void> dismiss();
  Future<void> setLocaleIdentifier(String? localeIdentifier);

  Future<FeatureAccess> hasFeature(
    String featureId, {
    double requiredBalance = 1,
    String? entityId,
    FeatureCheckPolicy policy = FeatureCheckPolicy.cacheFirst,
  });

  Future<FeatureConsumptionResult> consumeFeature(
    String featureId, {
    double quantity = 1,
    required String operationId,
    String? entityId,
  });

  Future<void> useFeature(
    String featureId, {
    double amount = 1,
    String? entityId,
    Map<String, Object?>? metadata,
  });

  Future<FeatureUsageResult> useFeatureAndWait(
    String featureId, {
    double amount = 1,
    String? entityId,
    bool setUsage = false,
    Map<String, Object?>? metadata,
  });

  Future<void> completePurchase(String requestId, PurchaseResult result);
  Future<void> completeRestore(String requestId, RestoreResult result);
}

class _UnsupportedNuxieFlutterPlatform extends NuxieFlutterPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Nuxie requires iOS or Android.');
}
