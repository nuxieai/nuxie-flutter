import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nuxie_flutter_native/nuxie_flutter_native.dart';
import 'package:nuxie_flutter_platform_interface/nuxie_flutter_platform_interface.dart';

abstract interface class NuxieClient {
  Future<void> configure(NuxieConfiguration configuration);
  bool get isConfigured;
  NuxieVersions get versions;
  ValueListenable<NuxieFeatureSnapshot> get features;
  Stream<NuxieActivityInfo> get activities;
  Stream<NuxieAppAction> get appActions;
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
  Future<RestoreResult> restorePurchases();
  Future<void> shutdown();
}

/// One process-owned native SDK connection. Subscribe before configuring.
final class Nuxie implements NuxieClient {
  Nuxie._();
  static final Nuxie instance = Nuxie._();
  NuxieFlutterPlatform? _platform;
  final _features = ValueNotifier(NuxieFeatureSnapshot.unknown());
  final _activities = StreamController<NuxieActivityInfo>.broadcast();
  final _actions = StreamController<NuxieAppAction>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  NuxieConfiguration? _configuration;
  Future<void>? _configuring;
  Future<void>? _stopping;
  bool _configured = false;
  String? _session;
  int _revision = -1;
  int _identityGeneration = -1;
  NuxieVersions _versions = const NuxieVersions(wrapper: '0.2.0');
  @override
  bool get isConfigured => _configured;
  @override
  NuxieVersions get versions => _versions;
  @override
  ValueListenable<NuxieFeatureSnapshot> get features => _features;
  @override
  Stream<NuxieActivityInfo> get activities => _activities.stream;
  @override
  Stream<NuxieAppAction> get appActions => _actions.stream;

  @override
  Future<void> configure(NuxieConfiguration configuration) {
    if (_stopping != null) {
      return Future.error(
        const NuxieException(
          code: 'shuttingDown',
          message: 'Wait for shutdown before configuring.',
        ),
      );
    }
    if (_configuration != null) {
      if (!_configuration!.equivalentTo(configuration)) {
        return Future.error(
          const NuxieException(
            code: 'alreadyConfigured',
            message: 'Configuration is immutable until shutdown.',
          ),
        );
      }
      return _configuring ?? Future.value();
    }
    if (kIsWeb ||
        ![
          TargetPlatform.iOS,
          TargetPlatform.android,
        ].contains(defaultTargetPlatform)) {
      return Future.error(
        const NuxieException(
          code: 'unsupportedPlatform',
          message: 'Nuxie supports the main Flutter engine on iOS and Android.',
        ),
      );
    }
    final apiKey = defaultTargetPlatform == TargetPlatform.iOS
        ? configuration.apiKeys.ios
        : configuration.apiKeys.android;
    if (apiKey.trim().isEmpty) {
      return Future.error(
        const NuxieException(
          code: 'invalidConfiguration',
          message: 'The active platform API key is empty.',
        ),
      );
    }
    _configuration = configuration;
    _configuring = _configure(configuration, apiKey);
    return _configuring!;
  }

  Future<void> _configure(
    NuxieConfiguration configuration,
    String apiKey,
  ) async {
    var nativeConfigured = false;
    try {
      // The platform singleton is a private test/implementation seam.
      if (!NuxieFlutterPlatform.isRegistered) registerNuxieFlutterNative();
      _platform = NuxieFlutterPlatform.instance;
      final platform = _platform!;
      final session = List.generate(
        24,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _session = session;
      _revision = -1;
      _identityGeneration = -1;
      _subscriptions.addAll([
        platform.featureSnapshots.listen((packet) {
          if (packet.session != _session ||
              packet.revision <= _revision ||
              packet.identityGeneration < _identityGeneration) {
            return;
          }
          _revision = packet.revision;
          _identityGeneration = packet.identityGeneration;
          _features.value = packet.value;
        }, onError: _featuresError),
        platform.activities.listen(
          _activities.add,
          onError: _activities.addError,
        ),
        platform.appActions.listen(_actions.add, onError: _actions.addError),
        platform.purchaseRequests.listen((request) {
          unawaited(_purchase(platform, session, configuration, request));
        }),
        platform.restoreRequests.listen((request) {
          unawaited(_restore(platform, session, configuration, request));
        }),
      ]);
      _versions = await _translate(
        () => platform.configure(
          apiKey: apiKey,
          options: configuration,
          usingPurchaseController: configuration.billing is ExternalBilling,
          wrapperVersion: '0.2.0',
          session: session,
        ),
      );
      nativeConfigured = true;
      if (_versions.contract != 2) {
        throw const NuxieException(
          code: 'incompatibleNativeContract',
          message: 'Native contract version must be 2.',
        );
      }
      _configured = true;
    } catch (_) {
      if (nativeConfigured) {
        try {
          await _platform!.shutdown();
        } catch (_) {
          // Preserve the setup failure; native shutdown can also lose its channel.
        }
      }
      await _unbind();
      _configuration = null;
      rethrow;
    } finally {
      _configuring = null;
    }
  }

  void _featuresError(Object error, StackTrace stack) {
    // A malformed native snapshot cannot remain an apparent access grant.
    _features.value = NuxieFeatureSnapshot.unknown();
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'nuxie_flutter',
        context: ErrorDescription('decoding native Feature state'),
      ),
    );
  }

  Future<void> _purchase(
    NuxieFlutterPlatform platform,
    String session,
    NuxieConfiguration configuration,
    NuxiePurchaseRequest request,
  ) async {
    PurchaseResult result;
    try {
      final billing = configuration.billing;
      result = billing is ExternalBilling
          ? await billing.controller.purchase(request.product)
          : const PurchaseResult.failed('purchaseControllerUnavailable');
    } catch (_) {
      result = const PurchaseResult.failed('purchaseControllerFailed');
    }
    if (_session == session) {
      try {
        await platform.completePurchase(request.requestId, result);
      } catch (_) {
        /* Native watchdog settles a disconnected callback. */
      }
    }
  }

  Future<void> _restore(
    NuxieFlutterPlatform platform,
    String session,
    NuxieConfiguration configuration,
    NuxieRestoreRequest request,
  ) async {
    RestoreResult result;
    try {
      final billing = configuration.billing;
      result = billing is ExternalBilling
          ? await billing.controller.restorePurchases()
          : const RestoreResult.failed('purchaseControllerUnavailable');
    } catch (_) {
      result = const RestoreResult.failed('purchaseControllerFailed');
    }
    if (_session == session) {
      try {
        await platform.completeRestore(request.requestId, result);
      } catch (_) {
        /* Native watchdog settles a disconnected callback. */
      }
    }
  }

  Future<T> _call<T>(Future<T> Function(NuxieFlutterPlatform) action) async {
    if (!_configured || _stopping != null) {
      throw const NuxieException(
        code: 'notConfigured',
        message: 'Configure Nuxie before issuing commands.',
      );
    }
    return _translate(() => action(_platform!));
  }

  Future<T> _translate<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (error) {
      throw NuxieException(
        code: error.code,
        message: error.message ?? 'Native SDK call failed.',
      );
    } on MissingPluginException {
      throw const NuxieException(
        code: 'nativeUnavailable',
        message: 'Rebuild the iOS or Android app with the native plugin.',
      );
    }
  }

  @override
  Future<void> identify(
    String distinctId, {
    Map<String, Object?>? userProperties,
    Map<String, Object?>? userPropertiesSetOnce,
  }) => _call(
    (p) => p.identify(
      _name(distinctId),
      userProperties: _json(userProperties),
      userPropertiesSetOnce: _json(userPropertiesSetOnce),
    ),
  );
  @override
  Future<void> reset({bool keepAnonymousId = false}) =>
      _call((p) => p.reset(keepAnonymousId: keepAnonymousId));
  @override
  Future<String> getDistinctId() => _call((p) => p.getDistinctId());
  @override
  Future<String> getAnonymousId() => _call((p) => p.getAnonymousId());
  @override
  Future<bool> getIsIdentified() => _call((p) => p.getIsIdentified());

  /// Acknowledges invocation, not durable capture or Journey completion.
  @override
  Future<void> trigger(String event, {Map<String, Object?>? properties}) =>
      _call((p) {
        if (event.startsWith(r'$')) {
          throw ArgumentError.value(event, 'event', 'Reserved SDK name');
        }
        return p.trigger(_name(event), properties: _json(properties));
      });
  @override
  Future<void> dismiss() => _call((p) => p.dismiss());
  @override
  Future<void> setLocaleIdentifier(String? localeIdentifier) =>
      _call((p) => p.setLocaleIdentifier(localeIdentifier));
  @override
  Future<FeatureAccess> hasFeature(
    String featureId, {
    double requiredBalance = 1,
    String? entityId,
    FeatureCheckPolicy policy = FeatureCheckPolicy.cacheFirst,
  }) => _call(
    (p) => p.hasFeature(
      _name(featureId),
      requiredBalance: _amount(requiredBalance),
      entityId: entityId,
      policy: policy,
    ),
  );
  @override
  Future<void> useFeature(
    String featureId, {
    double amount = 1,
    String? entityId,
    Map<String, Object?>? metadata,
  }) => _call(
    (p) => p.useFeature(
      _name(featureId),
      amount: _amount(amount),
      entityId: entityId,
      metadata: _json(metadata),
    ),
  );
  @override
  Future<FeatureUsageResult> useFeatureAndWait(
    String featureId, {
    double amount = 1,
    String? entityId,
    bool setUsage = false,
    Map<String, Object?>? metadata,
  }) => _call(
    (p) => p.useFeatureAndWait(
      _name(featureId),
      amount: _amount(amount),
      entityId: entityId,
      setUsage: setUsage,
      metadata: _json(metadata),
    ),
  );
  @override
  Future<RestoreResult> restorePurchases() =>
      _call((p) => p.restorePurchases());
  @override
  Future<void> shutdown() => _stopping ??= _shutdown();
  Future<void> _shutdown() async {
    try {
      try {
        await _configuring;
      } catch (_) {
        return;
      }
      if (_configured) await _translate(() => _platform!.shutdown());
    } finally {
      _configured = false;
      await _unbind();
      _configuration = null;
      _stopping = null;
    }
  }

  Future<void> _unbind() async {
    _session = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _features.value = NuxieFeatureSnapshot.unknown();
  }
}

String _name(String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, 'name', 'Must not be empty');
  }
  return value;
}

double _amount(double value) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(
      value,
      'amount',
      'Must be finite and nonnegative',
    );
  }
  return value;
}

Map<String, Object?>? _json(Map<String, Object?>? input) {
  Object? copy(Object? value, String path, Set<Object> ancestors) {
    if (value == null || value is String || value is bool || value is int) {
      return value;
    }
    if (value is double && value.isFinite) return value;
    if (value is Map || value is List) {
      if (!ancestors.add(value)) throw ArgumentError('Cyclic value at $path');
      try {
        if (value is List) {
          return List<Object?>.unmodifiable([
            for (var i = 0; i < value.length; i++)
              copy(value[i], '$path[$i]', ancestors),
          ]);
        }
        return Map<String, Object?>.unmodifiable(
          (value as Map).map((key, v) {
            if (key is! String) throw ArgumentError('Non-string key at $path');
            return MapEntry(key, copy(v, '$path.$key', ancestors));
          }),
        );
      } finally {
        ancestors.remove(value);
      }
    }
    throw ArgumentError('Non-JSON value at $path');
  }

  return input == null
      ? null
      : copy(input, r'$', Set.identity()) as Map<String, Object?>;
}
