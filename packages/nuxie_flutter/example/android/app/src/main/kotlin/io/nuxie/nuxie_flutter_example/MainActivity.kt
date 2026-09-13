package io.nuxie.nuxie_flutter_example

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.nuxie.flutter.nativeplugin.NuxieFlutterNativePlugin
import java.net.URI

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if ((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            intent.getStringExtra("nuxieLocalIngestUrl")?.let { value ->
                val uri = URI(value)
                require(uri.host in listOf("localhost", "127.0.0.1", "10.0.2.2"))
                NuxieFlutterNativePlugin.configureDevelopmentHost = { config ->
                    config.testingOverrides.apiEndpoint = uri.toURL()
                }
            }
        }
    }
}
