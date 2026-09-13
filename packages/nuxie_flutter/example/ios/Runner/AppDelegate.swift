import Flutter
import UIKit
#if DEBUG
@_spi(Testing) import Nuxie
import nuxie_flutter_native
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
#if DEBUG
    if let value = ProcessInfo.processInfo.environment["NUXIE_LOCAL_INGEST_URL"],
       let url = URL(string: value), ["localhost", "127.0.0.1"].contains(url.host ?? "") {
      NuxieFlutterNativePlugin.configureDevelopmentHost = { configuration in
        configuration.testingOverrides.apiEndpoint = url
      }
    }
#endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
