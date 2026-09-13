pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.10.1" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

include(":app")

// The source preview resolves the exact checkout prepared from NATIVE-PINS.json.
val nativePath = System.getenv("NUXIE_ANDROID_SDK_PATH")
    ?: file("../../../../.native/android").absolutePath
require(file(nativePath).isDirectory) {
    "Run python3 scripts/prepare-native.py from the Flutter repository first"
}
includeBuild(nativePath) {
    dependencySubstitution {
        substitute(module("ai.nuxie:nuxie-android")).using(project(":nuxie-android"))
    }
}
