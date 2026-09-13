package io.nuxie.flutter.nativeplugin

import ai.nuxie.sdk.AppAction
import ai.nuxie.sdk.AppActionValue
import ai.nuxie.sdk.LogLevel
import ai.nuxie.sdk.Nuxie
import ai.nuxie.sdk.NuxieActivityInfo
import ai.nuxie.sdk.NuxieActivityValue
import ai.nuxie.sdk.NuxieConfiguration
import ai.nuxie.sdk.NuxieEnvironment
import ai.nuxie.sdk.NuxieListener
import ai.nuxie.sdk.billing.NuxiePurchaseDelegate
import ai.nuxie.sdk.billing.PurchaseHandlingMode
import ai.nuxie.sdk.billing.PurchaseResult
import ai.nuxie.sdk.billing.RestoreResult
import ai.nuxie.sdk.billing.StoreProduct
import ai.nuxie.sdk.features.FeatureAccess
import ai.nuxie.sdk.features.FeatureCheckPolicy
import ai.nuxie.sdk.features.FeatureType
import ai.nuxie.sdk.features.FeatureUsageResult
import android.content.Context
import android.app.Activity
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

class NuxieFlutterNativePlugin : FlutterPlugin, ActivityAware, PNuxieHostApi {
  private var activity: Activity? = null
  override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
  override fun onDetachedFromActivity() { activity = null }
  override fun onDetachedFromActivityForConfigChanges() { activity = null }
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
  private lateinit var applicationContext: Context
  private var flutterApi: PNuxieFlutterApi? = null
  private val purchaseBridge = FlutterPurchaseDelegateBridge(
    emit = { request ->
      scope.launch {
        when (request) {
          is FlutterCommerceRequest.Purchase ->
            flutterApi?.onPurchaseRequest(request.value) { }
          is FlutterCommerceRequest.Restore ->
            flutterApi?.onRestoreRequest(request.value) { }
        }
      }
    },
  )
  private val sdkListener = object : NuxieListener {
    override fun onActivityEmitted(sdk: Nuxie, info: NuxieActivityInfo) {
      scope.launch { flutterApi?.onActivity(info.toPigeon()) { } }
    }

    override fun onAppActionRequested(sdk: Nuxie, action: AppAction) {
      scope.launch { flutterApi?.onAppAction(action.toPigeon()) { } }
    }
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = binding.applicationContext
    flutterApi = PNuxieFlutterApi(binding.binaryMessenger)
    PNuxieHostApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    PNuxieHostApi.setUp(binding.binaryMessenger, null)
    purchaseBridge.cancelPending("module_destroyed")
    if (Nuxie.listener === sdkListener) {
      Nuxie.listener = null
    }
    if (owner === this) { owner = null }
    snapshotJob?.cancel()
    flutterApi = null
    scope.cancel()
  }

  private var snapshotJob: Job? = null
  companion object {
    private var owner: NuxieFlutterNativePlugin? = null
    private var configurationKey: List<Any?>? = null
    /** Native debug-host seam; never a Dart configuration option. */
    var configureDevelopmentHost: ((NuxieConfiguration) -> Unit)? = null
  }

  override fun configure(request: PConfigureRequest, callback: (Result<PVersions>) -> Unit) {
    runCatching {
      val apiKey = requireNotNull(request.apiKey).also { require(it.isNotBlank()) }
      val session = requireNotNull(request.session)
      if (owner != null && owner !== this) throw FlutterError("engineAlreadyAttached", "Nuxie is owned by another engine", null)
      val key = listOf(apiKey, request.environment, request.logLevel, request.localeIdentifier,
        request.purchaseHandlingMode, request.usingPurchaseController)
      if (configurationKey != null && configurationKey != key) throw FlutterError("alreadyConfigured", "Shutdown before changing configuration", null)
      if (Nuxie.isSetup && configurationKey == null) throw FlutterError("alreadyConfigured", "Native SDK was configured outside this bridge", null)
      owner = this
      purchaseBridge.cancelPending("session_replaced")
      snapshotJob?.cancel()
      Nuxie.listener = sdkListener
      val config = configuration(apiKey, request)
      if ((applicationContext.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
        configureDevelopmentHost?.invoke(config)
      }
      if (Nuxie.isSetup) Nuxie.setPurchaseDelegate(config.purchaseDelegate)
      else Nuxie.setup(activity ?: applicationContext, config)
      configurationKey = key
      snapshotJob = scope.launch {
        Nuxie.features.snapshot.collect { value ->
          flutterApi?.onFeatureSnapshot(PFeatureSnapshot(
            session = session, identityGeneration = value.identityGeneration,
            revision = value.revision, state = when (value.state) {
              ai.nuxie.sdk.features.FeatureInfo.State.Unknown -> "unknown"
              ai.nuxie.sdk.features.FeatureInfo.State.Ready -> "ready"
              ai.nuxie.sdk.features.FeatureInfo.State.Reconciling -> "reconciling"
            }, all = value.all.mapValues { it.value.toPigeon() }
          )) { }
        }
      }
      PVersions(Nuxie.version, 2)
    }.onFailure {
      if (owner === this && !Nuxie.isSetup) {
        owner = null
        if (Nuxie.listener === sdkListener) Nuxie.listener = null
        snapshotJob?.cancel()
        purchaseBridge.cancelPending("setup_failed")
      }
    }.let(callback)
  }

  override fun restorePurchases(callback: (Result<PRestoreResult>) -> Unit) {
    scope.launch {
      runCatching { when (Nuxie.restorePurchases()) {
        RestoreResult.Restored -> PRestoreResult(type = "restored")
        RestoreResult.NoPurchases -> PRestoreResult(type = "no_purchases")
        is RestoreResult.Failed -> PRestoreResult(type = "failed", message = "restoreFailed")
      } }.let(callback)
    }
  }

  override fun shutdown(callback: (Result<Unit>) -> Unit) {
    snapshotJob?.cancel()
    configurationKey = null
    owner = null
    purchaseBridge.cancelPending("sdk_shutdown")
    scope.launch {
      runCatching {
        withContext(Dispatchers.Default) { Nuxie.shutdown() }
        if (Nuxie.listener === sdkListener) {
          Nuxie.listener = null
        }
      }.onSuccess {
        callback(Result.success(Unit))
      }.onFailure { error ->
        callback(Result.failure(error))
      }
    }
  }

  override fun identify(
    distinctId: String,
    userProperties: Map<String?, Any?>?,
    userPropertiesSetOnce: Map<String?, Any?>?,
    callback: (Result<Unit>) -> Unit,
  ) {
    runCatching {
      Nuxie.identify(
        distinctId = distinctId,
        userProperties = userProperties.stringKeyed(),
        userPropertiesSetOnce = userPropertiesSetOnce.stringKeyed(),
      )
    }.onSuccess {
      callback(Result.success(Unit))
    }.onFailure { callback(Result.failure(it)) }
  }

  override fun reset(keepAnonymousId: Boolean, callback: (Result<Unit>) -> Unit) {
    runCatching { Nuxie.reset(keepAnonymousId) }
      .onSuccess { callback(Result.success(Unit)) }
      .onFailure { callback(Result.failure(it)) }
  }

  override fun getDistinctId(callback: (Result<String>) -> Unit) {
    callback(Result.success(Nuxie.distinctId))
  }

  override fun getAnonymousId(callback: (Result<String>) -> Unit) {
    callback(Result.success(Nuxie.anonymousId))
  }

  override fun getIsIdentified(callback: (Result<Boolean>) -> Unit) {
    callback(Result.success(Nuxie.isIdentified))
  }

  override fun trigger(event: String, properties: Map<String?, Any?>?) {
    Nuxie.trigger(event, properties.stringKeyed())
  }

  override fun dismiss(callback: (Result<Unit>) -> Unit) {
    scope.launch {
      runCatching { Nuxie.dismiss() }
        .onSuccess { callback(Result.success(Unit)) }
        .onFailure { callback(Result.failure(it)) }
    }
  }

  override fun setLocaleIdentifier(
    localeIdentifier: String?,
    callback: (Result<Unit>) -> Unit,
  ) {
    scope.launch {
      runCatching { Nuxie.setLocaleIdentifier(localeIdentifier) }
        .onSuccess { callback(Result.success(Unit)) }
        .onFailure { callback(Result.failure(it)) }
    }
  }

  override fun hasFeature(
    featureId: String,
    requiredBalance: Double,
    entityId: String?,
    policy: String,
    callback: (Result<PFeatureAccess>) -> Unit,
  ) {
    scope.launch {
      runCatching {
        Nuxie.hasFeature(
          featureId = featureId,
          requiredBalance = requiredBalance,
          entityId = entityId,
          policy = if (policy == "remote") {
            FeatureCheckPolicy.REMOTE
          } else {
            FeatureCheckPolicy.CACHE_FIRST
          },
        ).toPigeon()
      }.onSuccess { callback(Result.success(it)) }
        .onFailure { callback(Result.failure(it)) }
    }
  }

  override fun useFeature(
    featureId: String,
    amount: Double,
    entityId: String?,
    metadata: Map<String?, Any?>?,
  ) {
    Nuxie.useFeature(
      featureId = featureId,
      amount = amount,
      entityId = entityId,
      metadata = metadata.stringKeyed(),
    )
  }

  override fun useFeatureAndWait(
    featureId: String,
    amount: Double,
    entityId: String?,
    setUsage: Boolean,
    metadata: Map<String?, Any?>?,
    callback: (Result<PFeatureUsageResult>) -> Unit,
  ) {
    scope.launch {
      runCatching {
        Nuxie.useFeatureAndWait(
          featureId = featureId,
          amount = amount,
          entityId = entityId,
          setUsage = setUsage,
          metadata = metadata.stringKeyed(),
        ).toPigeon()
      }.onSuccess { callback(Result.success(it)) }
        .onFailure { callback(Result.failure(it)) }
    }
  }

  override fun completePurchase(requestId: String, result: PPurchaseResult) {
    purchaseBridge.completePurchase(requestId, result)
  }

  override fun completeRestore(requestId: String, result: PRestoreResult) {
    purchaseBridge.completeRestore(requestId, result)
  }

  private fun configuration(
    apiKey: String,
    request: PConfigureRequest,
  ): NuxieConfiguration = NuxieConfiguration(apiKey).apply {
    environment = if (request.environment == "development") {
      NuxieEnvironment.DEVELOPMENT
    } else {
      NuxieEnvironment.PRODUCTION
    }
    logLevel = when (request.logLevel) {
      "verbose", "debug" -> LogLevel.DEBUG
      "info" -> LogLevel.INFO
      "error" -> LogLevel.ERROR
      "none" -> LogLevel.NONE
      else -> LogLevel.WARN
    }
    request.localeIdentifier?.let { localeIdentifier = it }
    purchaseHandlingMode = if (request.purchaseHandlingMode == "observer") {
      PurchaseHandlingMode.APP_MANAGED
    } else {
      PurchaseHandlingMode.NUXIE_MANAGED
    }
    if (request.usingPurchaseController == true) {
      purchaseDelegate = purchaseBridge
    }
  }
}

private fun Map<String?, Any?>?.stringKeyed(): Map<String, Any?>? =
  this?.entries?.mapNotNull { (key, value) -> key?.let { it to value } }?.toMap()

private fun FeatureAccess.toPigeon(): PFeatureAccess = PFeatureAccess(
  allowed = allowed,
  unlimited = unlimited,
  balance = balance,
  type = when (type) {
    FeatureType.BOOLEAN -> "boolean"
    FeatureType.METERED -> "metered"
    FeatureType.CREDIT_SYSTEM -> "creditSystem"
  },
)

private fun FeatureUsageResult.toPigeon(): PFeatureUsageResult = PFeatureUsageResult(
  success = success,
  featureId = featureId,
  amountUsed = amountUsed,
  message = message,
  usageCurrent = usage?.current,
  usageLimit = usage?.limit,
  usageRemaining = usage?.remaining,
  authoritativeAccess = authoritativeAccess?.toPigeon(),
)

private fun NuxieActivityInfo.toPigeon(): PActivityInfo = PActivityInfo(
  schemaVersion = NuxieActivityInfo.SCHEMA_VERSION.toLong(),
  id = id,
  timestampMs = timestampMillis,
  receivedAtMs = receivedAtMillis,
  name = name,
  properties = properties.mapValues { (_, value) -> value.bridgeValue },
)

private val NuxieActivityValue.bridgeValue: Any
  get() = when (this) {
    is NuxieActivityValue.String -> value
    is NuxieActivityValue.Int -> value
    is NuxieActivityValue.Double -> value
    is NuxieActivityValue.Bool -> value
  }

private fun AppAction.toPigeon(): PAppAction = PAppAction(
  name = name,
  payload = payload?.mapValues { (_, value) -> value.bridgeValue },
  experience = PExperienceRef(
    experienceId = experience.experienceId,
    experienceVersion = experience.experienceVersion,
    journeyId = experience.journeyId,
  ),
)

private val AppActionValue.bridgeValue: Any
  get() = when (this) {
    is AppActionValue.String -> value
    is AppActionValue.Int -> value
    is AppActionValue.Double -> value
    is AppActionValue.Bool -> value
  }

private sealed interface FlutterCommerceRequest {
  data class Purchase(val value: PPurchaseRequest) : FlutterCommerceRequest
  data class Restore(val value: PRestoreRequest) : FlutterCommerceRequest
}

private class FlutterPurchaseDelegateBridge(
  private val emit: (FlutterCommerceRequest) -> Unit,
  private val timeoutMs: Long = 120_000,
) : NuxiePurchaseDelegate {
  private val purchases = ConcurrentHashMap<String, CompletableDeferred<PurchaseResult>>()
  private val restores = ConcurrentHashMap<String, CompletableDeferred<RestoreResult>>()

  override suspend fun purchase(product: StoreProduct): PurchaseResult {
    val requestId = UUID.randomUUID().toString()
    val deferred = CompletableDeferred<PurchaseResult>()
    purchases[requestId] = deferred
    emit(
      FlutterCommerceRequest.Purchase(
        PPurchaseRequest(
          requestId = requestId,
          platform = "android",
          productId = product.productId,
          storeProductId = product.storeProductId,
          basePlanId = product.basePlanId,
          purchaseOptionId = product.purchaseOptionId,
          offerId = product.offerId,
          placementId = product.placementId,
          displayName = product.rawProduct?.name,
          description = product.rawProduct?.description,
          productType = product.rawProduct?.productType,
          displayPrice = null,
          timestampMs = System.currentTimeMillis(),
        ),
      ),
    )
    return try {
      withTimeoutOrNull(timeoutMs) { deferred.await() }
        ?: PurchaseResult.Failed(error("purchase_timeout"))
    } finally {
      purchases.remove(requestId)
    }
  }

  override suspend fun restorePurchases(): RestoreResult {
    val requestId = UUID.randomUUID().toString()
    val deferred = CompletableDeferred<RestoreResult>()
    restores[requestId] = deferred
    emit(
      FlutterCommerceRequest.Restore(
        PRestoreRequest(
          requestId = requestId,
          platform = "android",
          timestampMs = System.currentTimeMillis(),
        ),
      ),
    )
    return try {
      withTimeoutOrNull(timeoutMs) { deferred.await() }
        ?: RestoreResult.Failed(error("restore_timeout"))
    } finally {
      restores.remove(requestId)
    }
  }

  fun completePurchase(requestId: String, result: PPurchaseResult) {
    purchases.remove(requestId)?.complete(
      when (result.type?.lowercase()) {
        "purchased" -> PurchaseResult.Purchased
        "cancelled" -> PurchaseResult.Cancelled
        "pending" -> PurchaseResult.Pending
        else -> PurchaseResult.Failed(error(result.message ?: "purchase_failed"))
      },
    )
  }

  fun completeRestore(requestId: String, result: PRestoreResult) {
    restores.remove(requestId)?.complete(
      when (result.type?.lowercase()) {
        "restored" -> RestoreResult.Restored
        "no_purchases" -> RestoreResult.NoPurchases
        else -> RestoreResult.Failed(error(result.message ?: "restore_failed"))
      },
    )
  }

  fun cancelPending(reason: String) {
    purchases.values.forEach { it.complete(PurchaseResult.Failed(error(reason))) }
    restores.values.forEach { it.complete(RestoreResult.Failed(error(reason))) }
    purchases.clear()
    restores.clear()
  }

  private fun error(message: String): Throwable = IllegalStateException(message)
}
