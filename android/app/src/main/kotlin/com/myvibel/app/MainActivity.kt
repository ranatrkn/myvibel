package com.myvibel.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "gonderiReklam",
            GonderiReklamFactory(layoutInflater),
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "myvibel/ekran")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    val kilit = call.arguments as? Boolean ?: false
                    if (kilit) {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE,
                        )
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "gonderiReklam")
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
