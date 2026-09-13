import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/nuxie_bridge.g.dart',
    dartOptions: DartOptions(),
    dartPackageName: 'nuxie_flutter_native',
    kotlinOut:
        'android/src/main/kotlin/io/nuxie/flutter/nativeplugin/NuxieBridge.g.kt',
    kotlinOptions: KotlinOptions(package: 'io.nuxie.flutter.nativeplugin'),
    swiftOut:
        'ios/nuxie_flutter_native/Sources/nuxie_flutter_native/NuxieBridge.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
class PConfigureRequest {
  String? session;
  String? apiKey;
  String? wrapperVersion;
  bool? usingPurchaseController;
  String? environment;
  String? logLevel;
  String? localeIdentifier;
  String? purchaseHandlingMode;
}

class PFeatureAccess {
  bool? allowed;
  bool? unlimited;
  double? balance;
  String? type;
}

class PFeatureConsumptionResult {
  String? operationId;
  bool? accepted;
  String? code;
  double? quantity;
  double? balance;
  bool? unlimited;
  bool? active;
  bool? idempotentReplay;
}

class PFeatureUsageResult {
  bool? success;
  String? featureId;
  double? amountUsed;
  String? message;
  double? usageCurrent;
  double? usageLimit;
  double? usageRemaining;
  PFeatureAccess? authoritativeAccess;
}

class PFeatureSnapshot {
  String? session;
  int? identityGeneration;
  int? revision;
  String? state;
  Map<String?, PFeatureAccess?>? all;
}

class PVersions {
  String? nativeVersion;
  int? contract;
}

class PExperienceRef {
  String? experienceId;
  String? experienceVersion;
  String? journeyId;
}

class PAppAction {
  String? name;
  Map<String?, Object?>? payload;
  PExperienceRef? experience;
}

class PActivityInfo {
  int? schemaVersion;
  String? id;
  int? timestampMs;
  int? receivedAtMs;
  String? name;
  Map<String?, Object?>? properties;
}

class PPurchaseRequest {
  String? requestId;
  String? platform;
  String? productId;
  String? storeProductId;
  String? basePlanId;
  String? purchaseOptionId;
  String? offerId;
  String? placementId;
  String? displayName;
  String? description;
  String? productType;
  String? period;
  int? periodCount;
  PIntroductoryTerms? introductoryTerms;
  String? displayPrice;
  String? eligibilityJws;
  String? billingPlan;
  int? timestampMs;
}

class PRestoreRequest {
  String? requestId;
  String? platform;
  int? timestampMs;
}

class PPurchaseResult {
  String? type;
  String? message;
}

class PRestoreResult {
  String? type;
  String? message;
}

@HostApi()
abstract class PNuxieHostApi {
  @async
  PVersions configure(PConfigureRequest request);

  @async
  PRestoreResult restorePurchases();

  @async
  void shutdown();

  @async
  void identify(
    String distinctId,
    Map<String?, Object?>? userProperties,
    Map<String?, Object?>? userPropertiesSetOnce,
  );

  @async
  void reset(bool keepAnonymousId);

  @async
  String getDistinctId();

  @async
  String getAnonymousId();

  @async
  bool getIsIdentified();

  void trigger(String event, Map<String?, Object?>? properties);

  @async
  void dismiss();

  @async
  void setLocaleIdentifier(String? localeIdentifier);

  @async
  PFeatureAccess hasFeature(
    String featureId,
    double requiredBalance,
    String? entityId,
    String policy,
  );

  @async
  PFeatureConsumptionResult consumeFeature(
    String featureId,
    double quantity,
    String operationId,
    String? entityId,
  );

  void useFeature(
    String featureId,
    double amount,
    String? entityId,
    Map<String?, Object?>? metadata,
  );

  @async
  PFeatureUsageResult useFeatureAndWait(
    String featureId,
    double amount,
    String? entityId,
    bool setUsage,
    Map<String?, Object?>? metadata,
  );

  void completePurchase(String requestId, PPurchaseResult result);

  void completeRestore(String requestId, PRestoreResult result);
}

@FlutterApi()
abstract class PNuxieFlutterApi {
  void onFeatureSnapshot(PFeatureSnapshot snapshot);

  void onActivity(PActivityInfo activity);

  void onAppAction(PAppAction action);

  void onPurchaseRequest(PPurchaseRequest request);

  void onRestoreRequest(PRestoreRequest request);
}

class PIntroductoryTerms {
  String? price;
  String? period;
  int? periodCount;
  int? cycles;
  String? paymentMode;
  String? displayDuration;
}
