import Foundation
import Combine

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

#if canImport(Nuxie)
import Nuxie
#endif

public final class NuxieFlutterNativePlugin: NSObject, FlutterPlugin, PNuxieHostApi {
  private let flutterApi: PNuxieFlutterApi

#if canImport(Nuxie)
  private lazy var purchaseBridge = FlutterPurchaseDelegateBridge { [weak self] request in
    Task { @MainActor [weak self] in
      guard let self else { return }
      switch request {
      case .purchase(let value):
        self.flutterApi.onPurchaseRequest(request: value) { _ in }
      case .restore(let value):
        self.flutterApi.onRestoreRequest(request: value) { _ in }
      }
    }
  }

  @MainActor
  private lazy var delegateBridge = FlutterNuxieDelegate(flutterApi: flutterApi)
#endif

  init(binaryMessenger: FlutterBinaryMessenger) {
    flutterApi = PNuxieFlutterApi(binaryMessenger: binaryMessenger)
    super.init()
  }

  deinit {
    snapshotSubscription?.cancel()
#if canImport(Nuxie)
    purchaseBridge.cancelPending(reason: "engine_detached")
#endif
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = NuxieFlutterNativePlugin(binaryMessenger: registrar.messenger())
    PNuxieHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: plugin)
  }

  private var snapshotSubscription: AnyCancellable?
  private static var configurationKey: String?
#if DEBUG && canImport(Nuxie)
  /// Native test-host seam. The Dart API never accepts endpoint overrides.
  public static var configureDevelopmentHost: ((NuxieConfiguration) -> Void)?
#endif
  private static weak var owner: NuxieFlutterNativePlugin?

  func configure(request: PConfigureRequest, completion: @escaping (Result<PVersions, Error>) -> Void) {
#if canImport(Nuxie)
    Task { @MainActor in
      do {
        guard let apiKey = request.apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let session = request.session else {
          throw bridgeError("invalidConfiguration", "API key and session are required")
        }
        if let owner = Self.owner, owner !== self {
          throw bridgeError("engineAlreadyAttached", "Nuxie is owned by another Flutter engine")
        }
        let key = [apiKey, request.environment ?? "production", request.logLevel ?? "warning",
          request.localeIdentifier ?? "", request.purchaseHandlingMode ?? "full",
          String(request.usingPurchaseController ?? false)].joined(separator: "\u{0}")
        if let previous = Self.configurationKey, previous != key {
          throw bridgeError("alreadyConfigured", "Native configuration differs; shutdown first")
        }
        if NuxieSDK.shared.isSetup && Self.configurationKey == nil {
          throw bridgeError("alreadyConfigured", "Native SDK was configured outside this bridge")
        }
        Self.owner = self
        self.purchaseBridge.cancelPending(reason: "session_replaced")
        self.snapshotSubscription?.cancel()
        let configuration = self.configuration(apiKey: apiKey, request: request)
#if DEBUG
        Self.configureDevelopmentHost?(configuration)
#endif
        NuxieSDK.shared.delegate = self.delegateBridge
        if NuxieSDK.shared.isSetup {
          try NuxieSDK.shared.setPurchaseDelegate(configuration.purchaseDelegate)
        } else {
          try NuxieSDK.shared.setup(with: configuration)
        }
        Self.configurationKey = key
        self.snapshotSubscription = NuxieSDK.shared.features.$snapshot.sink { [weak self] value in
          self?.flutterApi.onFeatureSnapshot(snapshot: PFeatureSnapshot(
            session: session, identityGeneration: Int64(value.identityGeneration),
            revision: Int64(value.revision), state: String(describing: value.state),
            all: Dictionary(uniqueKeysWithValues: value.all.map { (Optional($0.key), Optional($0.value.pigeon)) })
          )) { _ in }
        }
        completion(.success(PVersions(nativeVersion: NuxieSDK.shared.version, contract: 2)))
      } catch {
        if !NuxieSDK.shared.isSetup { Self.owner = nil }
        completion(.failure(error))
      }
    }
#else
    completion(.failure(bridgeError("nativeUnavailable", "Nuxie iOS SDK is not linked")))
#endif
  }

  func restorePurchases(completion: @escaping (Result<PRestoreResult, Error>) -> Void) {
#if canImport(Nuxie)
    Task { @MainActor in
      let result = await NuxieSDK.shared.restorePurchases()
      switch result {
      case .restored: completion(.success(PRestoreResult(type: "restored")))
      case .noPurchases: completion(.success(PRestoreResult(type: "no_purchases")))
      case .failed: completion(.success(PRestoreResult(type: "failed", message: "restoreFailed")))
      }
    }
#else
    completion(.failure(bridgeError("nativeUnavailable", "Nuxie iOS SDK is not linked")))
#endif
  }

  func shutdown(completion: @escaping (Result<Void, Error>) -> Void) {
#if canImport(Nuxie)
    snapshotSubscription?.cancel()
    snapshotSubscription = nil
    Self.configurationKey = nil
    Self.owner = nil
    purchaseBridge.cancelPending(reason: "sdk_shutdown")
    Task {
      await NuxieSDK.shared.shutdown()
      await MainActor.run {
        NuxieSDK.shared.delegate = nil
      }
      completion(.success(()))
    }
#else
    completion(.success(()))
#endif
  }

  func identify(
    distinctId: String,
    userProperties: [String?: Any?]?,
    userPropertiesSetOnce: [String?: Any?]?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
#if canImport(Nuxie)
    NuxieSDK.shared.identify(
      distinctId,
      userProperties: userProperties?.stringKeyed,
      userPropertiesSetOnce: userPropertiesSetOnce?.stringKeyed
    )
    completion(.success(()))
#else
    completion(.failure(bridgeError("NATIVE_SDK_UNAVAILABLE", "Nuxie iOS SDK is not linked")))
#endif
  }

  func reset(
    keepAnonymousId: Bool,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
#if canImport(Nuxie)
    NuxieSDK.shared.reset(keepAnonymousId: keepAnonymousId)
    completion(.success(()))
#else
    completion(.failure(bridgeError("NATIVE_SDK_UNAVAILABLE", "Nuxie iOS SDK is not linked")))
#endif
  }

  func getDistinctId(completion: @escaping (Result<String, Error>) -> Void) {
#if canImport(Nuxie)
    completion(.success(NuxieSDK.shared.getDistinctId()))
#else
    completion(.failure(bridgeError("NATIVE_SDK_UNAVAILABLE", "Nuxie iOS SDK is not linked")))
#endif
  }

  func getAnonymousId(completion: @escaping (Result<String, Error>) -> Void) {
#if canImport(Nuxie)
    completion(.success(NuxieSDK.shared.getAnonymousId()))
#else
    completion(.failure(bridgeError("NATIVE_SDK_UNAVAILABLE", "Nuxie iOS SDK is not linked")))
#endif
  }

  func getIsIdentified(completion: @escaping (Result<Bool, Error>) -> Void) {
#if canImport(Nuxie)
    completion(.success(NuxieSDK.shared.isIdentified))
#else
    completion(.failure(bridgeError("NATIVE_SDK_UNAVAILABLE", "Nuxie iOS SDK is not linked")))
#endif
  }

  func trigger(event: String, properties: [String?: Any?]?) throws {
#if canImport(Nuxie)
    NuxieSDK.shared.trigger(event, properties: properties?.stringKeyed)
#endif
  }

  func dismiss(completion: @escaping (Result<Void, Error>) -> Void) {
#if canImport(Nuxie)
    Task { @MainActor in
      await NuxieSDK.shared.dismiss()
      completion(.success(()))
    }
#else
    completion(.success(()))
#endif
  }

  func setLocaleIdentifier(
    localeIdentifier: String?,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
#if canImport(Nuxie)
    Task {
      do {
        try await NuxieSDK.shared.setLocaleIdentifier(localeIdentifier)
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
#else
    completion(.failure(bridgeError("NATIVE_SDK_UNAVAILABLE", "Nuxie iOS SDK is not linked")))
#endif
  }

  func hasFeature(
    featureId: String,
    requiredBalance: Double,
    entityId: String?,
    policy: String,
    completion: @escaping (Result<PFeatureAccess, Error>) -> Void
  ) {
#if canImport(Nuxie)
    Task {
      do {
        let access = try await NuxieSDK.shared.hasFeature(
          featureId,
          requiredBalance: requiredBalance,
          entityId: entityId,
          policy: policy == "remote" ? .remote : .cacheFirst
        )
        completion(.success(access.pigeon))
      } catch {
        completion(.failure(error))
      }
    }
#else
    completion(.failure(bridgeError("NATIVE_SDK_UNAVAILABLE", "Nuxie iOS SDK is not linked")))
#endif
  }

  func useFeature(
    featureId: String,
    amount: Double,
    entityId: String?,
    metadata: [String?: Any?]?
  ) throws {
#if canImport(Nuxie)
    NuxieSDK.shared.useFeature(
      featureId,
      amount: amount,
      entityId: entityId,
      metadata: metadata?.stringKeyed
    )
#endif
  }

  func useFeatureAndWait(
    featureId: String,
    amount: Double,
    entityId: String?,
    setUsage: Bool,
    metadata: [String?: Any?]?,
    completion: @escaping (Result<PFeatureUsageResult, Error>) -> Void
  ) {
#if canImport(Nuxie)
    Task {
      do {
        let result = try await NuxieSDK.shared.useFeatureAndWait(
          featureId,
          amount: amount,
          entityId: entityId,
          setUsage: setUsage,
          metadata: metadata?.stringKeyed
        )
        completion(.success(result.pigeon))
      } catch {
        completion(.failure(error))
      }
    }
#else
    completion(.failure(bridgeError("NATIVE_SDK_UNAVAILABLE", "Nuxie iOS SDK is not linked")))
#endif
  }

  func completePurchase(requestId: String, result: PPurchaseResult) throws {
#if canImport(Nuxie)
    purchaseBridge.completePurchase(requestId: requestId, result: result)
#endif
  }

  func completeRestore(requestId: String, result: PRestoreResult) throws {
#if canImport(Nuxie)
    purchaseBridge.completeRestore(requestId: requestId, result: result)
#endif
  }

#if canImport(Nuxie)
  @MainActor
  private func configuration(
    apiKey: String,
    request: PConfigureRequest
  ) -> NuxieConfiguration {
    let value = NuxieConfiguration(apiKey: apiKey)
    value.environment = request.environment == "development" ? .development : .production
    if let logLevel = request.logLevel {
      value.logLevel = switch logLevel {
      case "verbose": .verbose
      case "debug": .debug
      case "info": .info
      case "error": .error
      case "none": .none
      default: .warning
      }
    }
    value.localeIdentifier = request.localeIdentifier
    value.purchaseHandlingMode = request.purchaseHandlingMode == "observer" ? .observer : .full
    if request.usingPurchaseController == true {
      value.purchaseDelegate = purchaseBridge
    }
    return value
  }
#endif
}

private func bridgeError(_ code: String, _ message: String) -> PigeonError {
  PigeonError(code: code, message: message, details: nil)
}

private extension Dictionary where Key == String?, Value == Any? {
  var stringKeyed: [String: Any] {
    reduce(into: [:]) { result, entry in
      if let key = entry.key, let value = entry.value {
        result[key] = value
      }
    }
  }
}

#if canImport(Nuxie)
@MainActor
private final class FlutterNuxieDelegate: NuxieDelegate {
  private let flutterApi: PNuxieFlutterApi

  init(flutterApi: PNuxieFlutterApi) {
    self.flutterApi = flutterApi
  }


  func nuxieDidEmit(_ info: NuxieActivityInfo) {
    flutterApi.onActivity(
      activity: PActivityInfo(
        schemaVersion: Int64(NuxieActivityInfo.schemaVersion),
        id: info.id,
        timestampMs: Int64(info.timestamp.timeIntervalSince1970 * 1_000),
        receivedAtMs: Int64(info.receivedAt.timeIntervalSince1970 * 1_000),
        name: info.name,
        properties: info.properties.reduce(into: [:]) { result, entry in
          result[entry.key] = entry.value.bridgeValue
        }
      )
    ) { _ in }
  }

  func nuxie(_ sdk: NuxieSDK, didRequestAppAction action: AppAction) {
    flutterApi.onAppAction(
      action: PAppAction(
        name: action.name,
        payload: action.payload?.reduce(into: [:]) { result, entry in
          result[entry.key] = entry.value.bridgeValue
        },
        experience: PExperienceRef(
          experienceId: action.experience.experienceId,
          experienceVersion: action.experience.experienceVersion,
          journeyId: action.experience.journeyId
        )
      )
    ) { _ in }
  }
}

private extension FeatureAccess {
  var pigeon: PFeatureAccess {
    PFeatureAccess(
      allowed: allowed,
      unlimited: unlimited,
      balance: balance,
      type: type.rawValue
    )
  }
}

private extension FeatureUsageResult {
  var pigeon: PFeatureUsageResult {
    PFeatureUsageResult(
      success: success,
      featureId: featureId,
      amountUsed: amountUsed,
      message: message,
      usageCurrent: usage?.current,
      usageLimit: usage?.limit,
      usageRemaining: usage?.remaining,
      authoritativeAccess: authoritativeAccess?.pigeon
    )
  }
}

private extension NuxieActivityValue {
  var bridgeValue: Any {
    switch self {
    case .string(let value): value
    case .int(let value): value
    case .double(let value): value
    case .bool(let value): value
    }
  }
}

private extension AppActionValue {
  var bridgeValue: Any {
    switch self {
    case .string(let value): value
    case .int(let value): value
    case .double(let value): value
    case .bool(let value): value
    }
  }
}

private enum FlutterCommerceRequest {
  case purchase(PPurchaseRequest)
  case restore(PRestoreRequest)
}

private final class FlutterPurchaseDelegateBridge: NuxiePurchaseDelegate, @unchecked Sendable {
  private let emit: (FlutterCommerceRequest) -> Void
  private let timeoutSeconds: TimeInterval
  private let lock = NSLock()
  private var purchases: [String: CheckedContinuation<PurchaseResult, Never>] = [:]
  private var restores: [String: CheckedContinuation<RestoreResult, Never>] = [:]

  init(
    timeoutSeconds: TimeInterval = 120,
    emit: @escaping (FlutterCommerceRequest) -> Void
  ) {
    self.timeoutSeconds = timeoutSeconds
    self.emit = emit
  }

  func purchase(product: StoreProduct) async -> PurchaseResult {
    let requestId = UUID().uuidString
    let request = PPurchaseRequest(
      requestId: requestId,
      platform: "ios",
      productId: product.productId,
      storeProductId: product.storeProductId,
      basePlanId: nil,
      purchaseOptionId: nil,
      offerId: nil,
      placementId: product.placementId,
      displayName: product.name,
      description: product.description,
      productType: product.productType.rawValue,
      period: product.period?.rawValue,
      periodCount: product.periodCount.map(Int64.init),
      introductoryTerms: product.introductoryTerms.map { terms in
        PIntroductoryTerms(price: terms.price, period: terms.period.rawValue,
          periodCount: Int64(terms.periodCount), cycles: Int64(terms.cycles),
          paymentMode: terms.paymentMode.rawValue, displayDuration: terms.trialPeriodText)
      },
      displayPrice: product.price,
      eligibilityJws: product.introductoryOfferEligibilityJWS,
      billingPlan: product.billingPlan.rawValue,
      timestampMs: Int64(Date().timeIntervalSince1970 * 1_000)
    )
    return await withCheckedContinuation { continuation in
      lock.withLock { purchases[requestId] = continuation }
      emit(.purchase(request))
      schedulePurchaseTimeout(requestId)
    }
  }

  func restorePurchases() async -> RestoreResult {
    let requestId = UUID().uuidString
    let request = PRestoreRequest(
      requestId: requestId,
      platform: "ios",
      timestampMs: Int64(Date().timeIntervalSince1970 * 1_000)
    )
    return await withCheckedContinuation { continuation in
      lock.withLock { restores[requestId] = continuation }
      emit(.restore(request))
      scheduleRestoreTimeout(requestId)
    }
  }

  func completePurchase(requestId: String, result: PPurchaseResult) {
    let continuation = lock.withLock { purchases.removeValue(forKey: requestId) }
    let outcome: PurchaseResult = switch result.type?.lowercased() {
    case "purchased": .purchased
    case "cancelled": .cancelled
    case "pending": .pending
    default: .failed(error(result.message ?? "purchase_failed"))
    }
    continuation?.resume(returning: outcome)
  }

  func completeRestore(requestId: String, result: PRestoreResult) {
    let continuation = lock.withLock { restores.removeValue(forKey: requestId) }
    let outcome: RestoreResult = switch result.type?.lowercased() {
    case "restored": .restored
    case "no_purchases": .noPurchases
    default: .failed(error(result.message ?? "restore_failed"))
    }
    continuation?.resume(returning: outcome)
  }

  func cancelPending(reason: String) {
    let pending = lock.withLock {
      let pending = (Array(purchases.values), Array(restores.values))
      purchases.removeAll()
      restores.removeAll()
      return pending
    }
    pending.0.forEach { $0.resume(returning: .failed(error(reason))) }
    pending.1.forEach { $0.resume(returning: .failed(error(reason))) }
  }

  private func schedulePurchaseTimeout(_ requestId: String) {
    Task { [weak self] in
      guard let self else { return }
      try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
      let continuation = self.lock.withLock { self.purchases.removeValue(forKey: requestId) }
      continuation?.resume(returning: .failed(self.error("purchase_timeout")))
    }
  }

  private func scheduleRestoreTimeout(_ requestId: String) {
    Task { [weak self] in
      guard let self else { return }
      try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
      let continuation = self.lock.withLock { self.restores.removeValue(forKey: requestId) }
      continuation?.resume(returning: .failed(self.error("restore_timeout")))
    }
  }

  private func error(_ message: String) -> Error {
    NSError(
      domain: "io.nuxie.flutter",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }
}
#endif
