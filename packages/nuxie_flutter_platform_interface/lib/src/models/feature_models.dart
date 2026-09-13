import 'package:flutter/foundation.dart';

enum FeatureCheckPolicy { cacheFirst, remote }

enum FeatureType { boolean, metered, creditSystem }

class FeatureAccess {
  const FeatureAccess({
    required this.allowed,
    required this.unlimited,
    required this.type,
    this.balance,
  });

  final bool allowed;
  final bool unlimited;
  final double? balance;
  final FeatureType type;
  @override
  bool operator ==(Object other) =>
      other is FeatureAccess &&
      allowed == other.allowed &&
      unlimited == other.unlimited &&
      balance == other.balance &&
      type == other.type;
  @override
  int get hashCode => Object.hash(allowed, unlimited, balance, type);
}

class FeatureUsageInfo {
  const FeatureUsageInfo({required this.current, this.limit, this.remaining});

  final double current;
  final double? limit;
  final double? remaining;
}

class FeatureUsageResult {
  const FeatureUsageResult({
    required this.success,
    required this.featureId,
    required this.amountUsed,
    this.message,
    this.usage,
    this.authoritativeAccess,
  });

  final bool success;
  final String featureId;
  final double amountUsed;
  final String? message;
  final FeatureUsageInfo? usage;
  final FeatureAccess? authoritativeAccess;
}

enum FeatureState { unknown, reconciling, ready }

/// One immutable native publication. This map is globally scoped.
final class NuxieFeatureSnapshot {
  NuxieFeatureSnapshot({
    required this.state,
    required Map<String, FeatureAccess> all,
  }) : all = Map.unmodifiable(all);
  NuxieFeatureSnapshot.unknown() : state = FeatureState.unknown, all = const {};
  final FeatureState state;
  final Map<String, FeatureAccess> all;
  FeatureAccess? operator [](String featureId) => all[featureId];
  @override
  bool operator ==(Object other) =>
      other is NuxieFeatureSnapshot &&
      state == other.state &&
      mapEquals(all, other.all);
  @override
  int get hashCode => Object.hash(
    state,
    Object.hashAllUnordered(
      all.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// Private transport publication metadata, not a customer identity.
final class NativeFeatureSnapshot {
  const NativeFeatureSnapshot({
    required this.session,
    required this.identityGeneration,
    required this.revision,
    required this.value,
  });
  final String session;
  final int identityGeneration;
  final int revision;
  final NuxieFeatureSnapshot value;
}

/// A committed decision; accepted remains true when the final unit was spent.
class FeatureConsumptionResult {
  const FeatureConsumptionResult({
    required this.operationId,
    required this.customerId,
    required this.featureId,
    this.occurredAtMs,
    required this.accepted,
    required this.code,
    required this.quantity,
    this.balance,
    required this.unlimited,
    required this.active,
    required this.idempotentReplay,
  });
  final String operationId;
  final String customerId;
  final String featureId;
  final double? occurredAtMs;
  final bool accepted;
  final String code;
  final double quantity;
  final double? balance;
  final bool unlimited;
  final bool active;
  final bool idempotentReplay;
}
