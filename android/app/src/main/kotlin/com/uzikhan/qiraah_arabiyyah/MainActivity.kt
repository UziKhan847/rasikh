package com.uzikhan.qiraah_arabiyyah

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Android leaves many phones (Samsung especially) at 60 Hz unless the app asks
// for more. On start, ask for the screen's fastest mode at its resolution.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferFastestMode()
    }

    // The screen's rotation (Surface.ROTATION_0…270): which way round a phone
    // on its side is held, so the muṣḥaf's toolbar goes on the side away
    // from the camera.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qiraah/display")
            .setMethodCallHandler { call, result ->
                if (call.method == "rotation") {
                    val d: Display? =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display
                        else @Suppress("DEPRECATION") windowManager.defaultDisplay
                    result.success(d?.rotation ?: 0)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun preferFastestMode() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val display: Display =
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else null)
                ?: @Suppress("DEPRECATION") windowManager.defaultDisplay
        val now = display.mode
        val pick = display.supportedModes
            .filter { it.physicalWidth == now.physicalWidth && it.physicalHeight == now.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: return
        val attrs = window.attributes
        if (attrs.preferredDisplayModeId != pick.modeId) {
            attrs.preferredDisplayModeId = pick.modeId
            window.attributes = attrs
        }
    }
}
