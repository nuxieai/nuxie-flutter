import 'purchase_models.dart';

enum NuxieEnvironment { production, development }

enum NuxieLogLevel { debug, info, warning, error, none }

enum PurchaseHandlingMode { full, observer }

final class NuxieApiKeys {
  const NuxieApiKeys({required this.ios, required this.android});
  final String ios;
  final String android;
}

sealed class NuxieBilling {
  const NuxieBilling();
  const factory NuxieBilling.native({PurchaseHandlingMode handling}) =
      NativeBilling;
  const factory NuxieBilling.external(NuxiePurchaseController controller) =
      ExternalBilling;
}

final class NativeBilling extends NuxieBilling {
  const NativeBilling({this.handling = PurchaseHandlingMode.full});
  final PurchaseHandlingMode handling;
}

final class ExternalBilling extends NuxieBilling {
  const ExternalBilling(this.controller);
  final NuxiePurchaseController controller;
}

/// Immutable setup configuration; native SDKs own runtime behavior.
final class NuxieConfiguration {
  const NuxieConfiguration({
    required this.apiKeys,
    this.environment = NuxieEnvironment.production,
    this.logLevel = NuxieLogLevel.warning,
    this.localeIdentifier,
    this.billing = const NuxieBilling.native(),
  });
  final NuxieApiKeys apiKeys;
  final NuxieEnvironment environment;
  final NuxieLogLevel logLevel;
  final String? localeIdentifier;
  final NuxieBilling billing;

  bool equivalentTo(NuxieConfiguration other) =>
      apiKeys.ios == other.apiKeys.ios &&
      apiKeys.android == other.apiKeys.android &&
      environment == other.environment &&
      logLevel == other.logLevel &&
      localeIdentifier == other.localeIdentifier &&
      switch ((billing, other.billing)) {
        (NativeBilling a, NativeBilling b) => a.handling == b.handling,
        (ExternalBilling a, ExternalBilling b) => identical(
          a.controller,
          b.controller,
        ),
        _ => false,
      };
}

final class NuxieVersions {
  const NuxieVersions({required this.wrapper, this.native, this.contract});
  final String wrapper;
  final String? native;
  final int? contract;
}
