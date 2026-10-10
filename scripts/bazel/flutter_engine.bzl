"""Native compile imports from the same pinned Flutter SDK as the Dart graph."""

def _engine_impl(ctx):
    # The host alias is a source-file symlink into the verified SDK archive.
    sdk = ctx.path(ctx.attr.launcher).realpath.dirname.dirname
    engine = sdk.get_child("bin/cache/artifacts/engine")
    if ctx.attr.platform == "ios":
        framework = engine.get_child("ios/Flutter.xcframework")
        if not framework.exists:
            fail("The pinned Flutter SDK needs precache = [\"ios\"]")
        ctx.watch_tree(framework)
        ctx.symlink(framework, "Flutter.xcframework")
        ctx.file("BUILD.bazel", '''load("@rules_apple//apple:apple.bzl", "apple_dynamic_xcframework_import")
package(default_visibility = ["//visibility:public"])
apple_dynamic_xcframework_import(name = "embedding", xcframework_imports = glob(["Flutter.xcframework/**"]))
''')
    else:
        jar = engine.get_child("android-arm64/flutter.jar")
        if not jar.exists:
            fail("The pinned Flutter SDK needs precache = [\"android\"]")
        ctx.watch(jar)
        ctx.symlink(jar, "flutter.jar")
        ctx.file("BUILD.bazel", '''load("@rules_java//java:java_import.bzl", "java_import")
package(default_visibility = ["//visibility:public"])
java_import(name = "embedding", jars = ["flutter.jar"])
''')

_engine = repository_rule(
    implementation = _engine_impl,
    attrs = {
        "launcher": attr.label(default = Label("@flutter_sdk//:bin/flutter"), allow_single_file = True),
        "platform": attr.string(mandatory = True, values = ["ios", "android"]),
    },
    local = True,
)

def _engines_impl(ctx):
    _engine(name = "nuxie_flutter_engine_ios", platform = "ios")
    _engine(name = "nuxie_flutter_engine_android", platform = "android")

flutter_engines = module_extension(implementation = _engines_impl)
