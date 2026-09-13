import 'package:nuxie_flutter_platform_interface/nuxie_flutter_platform_interface.dart';

import 'generated/nuxie_bridge.g.dart';

PConfigureRequest toConfigureRequest({
  required String apiKey,
  required String wrapperVersion,
  required bool usingPurchaseController,
  required NuxieConfiguration options,
  required String session,
}) => PConfigureRequest(
  session: session,
  apiKey: apiKey,
  wrapperVersion: wrapperVersion,
  usingPurchaseController: usingPurchaseController,
  environment: options.environment.name,
  logLevel: options.logLevel.name,
  localeIdentifier: options.localeIdentifier,
  purchaseHandlingMode: options.billing is NativeBilling
      ? (options.billing as NativeBilling).handling.name
      : 'full',
);

T requiredField<T>(T? value, String name) {
  if (value == null) {
    throw NuxieException(
      code: 'incompatibleNativeContract',
      message: 'Native response omitted $name.',
    );
  }
  return value;
}

FeatureAccess fromFeatureAccess(PFeatureAccess value) {
  return FeatureAccess(
    allowed: requiredField(value.allowed, 'allowed'),
    unlimited: requiredField(value.unlimited, 'unlimited'),
    balance: value.balance,
    type: FeatureType.values.byName(requiredField(value.type, 'type')),
  );
}

FeatureConsumptionResult fromFeatureConsumptionResult(
  PFeatureConsumptionResult value,
) => FeatureConsumptionResult(
  operationId: requiredField(value.operationId, 'operationId'),
  customerId: requiredField(value.customerId, 'customerId'),
  featureId: requiredField(value.featureId, 'featureId'),
  occurredAtMs: value.occurredAtMs,
  accepted: requiredField(value.accepted, 'accepted'),
  code: requiredField(value.code, 'code'),
  quantity: requiredField(value.quantity, 'quantity'),
  balance: value.balance,
  unlimited: requiredField(value.unlimited, 'unlimited'),
  active: requiredField(value.active, 'active'),
  idempotentReplay: requiredField(value.idempotentReplay, 'idempotentReplay'),
);

FeatureUsageResult fromFeatureUsageResult(PFeatureUsageResult value) {
  final usage = value.usageCurrent == null
      ? null
      : FeatureUsageInfo(
          current: value.usageCurrent!,
          limit: value.usageLimit,
          remaining: value.usageRemaining,
        );
  return FeatureUsageResult(
    success: requiredField(value.success, 'success'),
    featureId: requiredField(value.featureId, 'featureId'),
    amountUsed: requiredField(value.amountUsed, 'amountUsed'),
    message: value.message,
    usage: usage,
    authoritativeAccess: value.authoritativeAccess == null
        ? null
        : fromFeatureAccess(value.authoritativeAccess!),
  );
}

NativeFeatureSnapshot fromFeatureSnapshot(PFeatureSnapshot value) =>
    NativeFeatureSnapshot(
      session: requiredField(value.session, 'session'),
      identityGeneration: requiredField(
        value.identityGeneration,
        'identityGeneration',
      ),
      revision: requiredField(value.revision, 'revision'),
      value: NuxieFeatureSnapshot(
        state: FeatureState.values.byName(requiredField(value.state, 'state')),
        all: requiredField(value.all, 'all').map(
          (key, access) => MapEntry(
            requiredField(key, 'featureId'),
            fromFeatureAccess(requiredField(access, 'access')),
          ),
        ),
      ),
    );

RestoreResult fromRestoreResult(PRestoreResult value) => switch (value.type) {
  'restored' => const RestoreResult.restored(),
  'no_purchases' => const RestoreResult.noPurchases(),
  'failed' => RestoreResult.failed(value.message ?? 'restoreFailed'),
  _ => throw const NuxieException(
    code: 'incompatibleNativeContract',
    message: 'Unknown restore result.',
  ),
};

NuxieActivityInfo fromActivityInfo(PActivityInfo value) {
  return NuxieActivityInfo(
    schemaVersion: requiredField(value.schemaVersion, 'schemaVersion'),
    id: requiredField(value.id, 'id'),
    timestampMs: requiredField(value.timestampMs, 'timestampMs'),
    receivedAtMs: requiredField(value.receivedAtMs, 'receivedAtMs'),
    name: requiredField(value.name, 'name'),
    properties: _scalarMap(value.properties),
  );
}

NuxieAppAction fromAppAction(PAppAction value) {
  final experience = value.experience;
  if (experience == null) {
    throw StateError('App Action omitted its Experience reference');
  }
  return NuxieAppAction(
    name: requiredField(value.name, 'name'),
    payload: value.payload == null ? null : _scalarMap(value.payload),
    experience: ExperienceRef(
      experienceId: requiredField(experience.experienceId, 'experienceId'),
      experienceVersion: experience.experienceVersion,
      journeyId: experience.journeyId,
    ),
  );
}

NuxiePurchaseRequest fromPurchaseRequest(PPurchaseRequest value) {
  return NuxiePurchaseRequest(
    requestId: requiredField(value.requestId, 'requestId'),
    platform: requiredField(value.platform, 'platform'),
    productId: requiredField(value.productId, 'productId'),
    storeProductId: requiredField(value.storeProductId, 'storeProductId'),
    basePlanId: value.basePlanId,
    purchaseOptionId: value.purchaseOptionId,
    offerId: value.offerId,
    placementId: value.placementId,
    displayName: value.displayName,
    description: value.description,
    productType: value.productType,
    period: value.period,
    periodCount: value.periodCount,
    introductoryTerms: value.introductoryTerms == null
        ? null
        : fromIntroductoryTerms(value.introductoryTerms!),
    displayPrice: value.displayPrice,
    eligibilityJws: value.eligibilityJws,
    billingPlan: value.billingPlan,
    timestampMs: requiredField(value.timestampMs, 'timestampMs'),
  );
}

NuxieRestoreRequest fromRestoreRequest(PRestoreRequest value) {
  return NuxieRestoreRequest(
    requestId: requiredField(value.requestId, 'requestId'),
    platform: requiredField(value.platform, 'platform'),
    timestampMs: requiredField(value.timestampMs, 'timestampMs'),
  );
}

PPurchaseResult toPurchaseResult(PurchaseResult value) {
  return PPurchaseResult(type: value.type.name, message: value.message);
}

PRestoreResult toRestoreResult(RestoreResult value) {
  return PRestoreResult(
    type: switch (value.type) {
      RestoreResultType.restored => 'restored',
      RestoreResultType.noPurchases => 'no_purchases',
      RestoreResultType.failed => 'failed',
    },
    message: value.message,
  );
}

Map<String, Object> _scalarMap(Map<String?, Object?>? values) {
  final result = <String, Object>{};
  for (final entry in values?.entries ?? const <MapEntry<String?, Object?>>[]) {
    final key = entry.key;
    final value = entry.value;
    if (key != null && value != null) {
      result[key] = value;
    }
  }
  return result;
}

NuxieIntroductoryTerms fromIntroductoryTerms(PIntroductoryTerms value) =>
    NuxieIntroductoryTerms(
      price: requiredField(value.price, 'introductoryTerms.price'),
      period: requiredField(value.period, 'introductoryTerms.period'),
      periodCount: requiredField(
        value.periodCount,
        'introductoryTerms.periodCount',
      ),
      cycles: requiredField(value.cycles, 'introductoryTerms.cycles'),
      paymentMode: requiredField(
        value.paymentMode,
        'introductoryTerms.paymentMode',
      ),
      displayDuration: requiredField(
        value.displayDuration,
        'introductoryTerms.displayDuration',
      ),
    );
