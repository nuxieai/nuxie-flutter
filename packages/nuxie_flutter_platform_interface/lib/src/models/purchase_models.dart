enum PurchaseResultType { purchased, cancelled, pending, failed }

class NuxiePurchaseRequest {
  const NuxiePurchaseRequest({
    required this.requestId,
    required this.platform,
    required this.productId,
    required this.storeProductId,
    required this.timestampMs,
    this.basePlanId,
    this.purchaseOptionId,
    this.offerId,
    this.placementId,
    this.displayName,
    this.description,
    this.productType,
    this.period,
    this.periodCount,
    this.introductoryTerms,
    this.displayPrice,
    this.billingPlan,
    this.eligibilityJws,
  });

  final String requestId;
  final String platform;
  final String productId;
  final String storeProductId;
  final String? basePlanId;
  final String? purchaseOptionId;
  final String? offerId;
  final String? placementId;
  final String? displayName;
  final String? description;
  final String? productType;
  final String? period;
  final int? periodCount;
  final NuxieIntroductoryTerms? introductoryTerms;
  final String? displayPrice;
  final String? billingPlan;
  final String? eligibilityJws;
  final int timestampMs;
  NuxieStoreProduct get product => NuxieStoreProduct(
    productId: productId,
    storeProductId: storeProductId,
    platform: platform,
    basePlanId: basePlanId,
    purchaseOptionId: purchaseOptionId,
    offerId: offerId,
    placementId: placementId,
    displayName: displayName,
    description: description,
    productType: productType,
    period: period,
    periodCount: periodCount,
    introductoryTerms: introductoryTerms,
    displayPrice: displayPrice,
    eligibilityJws: eligibilityJws,
    billingPlan: billingPlan,
  );
}

sealed class PurchaseResult {
  const PurchaseResult();
  const factory PurchaseResult.purchased() = PurchaseSucceeded;
  const factory PurchaseResult.cancelled() = PurchaseCancelled;
  const factory PurchaseResult.pending() = PurchasePending;
  const factory PurchaseResult.failed(String message) = PurchaseFailed;
  PurchaseResultType get type;
  String? get message => null;
}
final class PurchaseSucceeded extends PurchaseResult {
  const PurchaseSucceeded();
  @override
  PurchaseResultType get type => PurchaseResultType.purchased;
}
final class PurchaseCancelled extends PurchaseResult {
  const PurchaseCancelled();
  @override
  PurchaseResultType get type => PurchaseResultType.cancelled;
}
final class PurchasePending extends PurchaseResult {
  const PurchasePending();
  @override
  PurchaseResultType get type => PurchaseResultType.pending;
}
final class PurchaseFailed extends PurchaseResult {
  const PurchaseFailed(this.message);
  @override
  final String message;
  @override
  PurchaseResultType get type => PurchaseResultType.failed;
}

enum RestoreResultType { restored, noPurchases, failed }

class NuxieRestoreRequest {
  const NuxieRestoreRequest({
    required this.requestId,
    required this.platform,
    required this.timestampMs,
  });

  final String requestId;
  final String platform;
  final int timestampMs;
}

sealed class RestoreResult {
  const RestoreResult();
  const factory RestoreResult.restored() = PurchasesRestored;
  const factory RestoreResult.noPurchases() = NoPurchasesToRestore;
  const factory RestoreResult.failed(String message) = RestoreFailed;
  RestoreResultType get type;
  String? get message => null;
}
final class PurchasesRestored extends RestoreResult {
  const PurchasesRestored();
  @override
  RestoreResultType get type => RestoreResultType.restored;
}
final class NoPurchasesToRestore extends RestoreResult {
  const NoPurchasesToRestore();
  @override
  RestoreResultType get type => RestoreResultType.noPurchases;
}
final class RestoreFailed extends RestoreResult {
  const RestoreFailed(this.message);
  @override
  final String message;
  @override
  RestoreResultType get type => RestoreResultType.failed;
}

/// The app's existing billing provider owns checkout and restore.
abstract interface class NuxiePurchaseController {
  Future<PurchaseResult> purchase(NuxieStoreProduct product);
  Future<RestoreResult> restorePurchases();
}

final class NuxieStoreProduct {
  const NuxieStoreProduct({
    required this.productId,
    required this.storeProductId,
    required this.platform,
    this.basePlanId,
    this.purchaseOptionId,
    this.offerId,
    this.placementId,
    this.displayName,
    this.description,
    this.productType,
    this.period,
    this.periodCount,
    this.introductoryTerms,
    this.displayPrice,
    this.billingPlan,
    this.eligibilityJws,
  });
  final String productId;
  final String storeProductId;
  final String platform;
  final String? basePlanId;
  final String? purchaseOptionId;
  final String? offerId;
  final String? placementId;
  final String? displayName;
  final String? description;
  final String? productType;
  final String? period;
  final int? periodCount;
  final NuxieIntroductoryTerms? introductoryTerms;
  final String? displayPrice;
  final String? billingPlan;
  final String? eligibilityJws;
}

/// Live introductory terms when exposed by the selected native product.
final class NuxieIntroductoryTerms {
  const NuxieIntroductoryTerms({required this.price, required this.period,
    required this.periodCount, required this.cycles, required this.paymentMode,
    required this.displayDuration});
  final String price;
  final String period;
  final int periodCount;
  final int cycles;
  final String paymentMode;
  final String displayDuration;
}
