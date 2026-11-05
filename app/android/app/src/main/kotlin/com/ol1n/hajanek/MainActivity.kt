package com.ol1n.hajanek

import android.app.UiModeManager
import android.content.res.Configuration
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service needs its activity subclass to share the FlutterEngine with the service.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Phone or TV (lib/core/form_factor.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ol1n.hajanek/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> {
                        val ui = getSystemService(UI_MODE_SERVICE) as UiModeManager
                        result.success(ui.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
