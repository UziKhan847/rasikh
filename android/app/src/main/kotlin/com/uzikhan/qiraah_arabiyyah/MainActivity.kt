package com.uzikhan.qiraah_arabiyyah

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

// Android leaves many phones (Samsung especially) at 60 Hz unless the app asks
// for more. On start, ask for the screen's fastest mode at its resolution.
// Kids Mode's Ultra asks for 60 instead through the "qiraah/display" channel
// (lib/core/display_rate.dart): an even 60 looks smoother than frames that
// keep missing a 120 Hz deadline.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyRate(max = true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qiraah/display")
            .setMethodCallHandler { call, result ->
                if (call.method == "setRate") {
                    result.success(applyRate(max = call.arguments != "60"))
                } else {
                    result.notImplemented()
                }
            }
    }

    /** Asks for the fastest mode (or the one nearest 60 Hz) at the current
     *  resolution; returns its refresh rate, or 0 where it cannot ask. */
    private fun applyRate(max: Boolean): Double {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return 0.0
        val display: Display =
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else null)
                ?: @Suppress("DEPRECATION") windowManager.defaultDisplay
        val now = display.mode
        val same = display.supportedModes.filter {
            it.physicalWidth == now.physicalWidth && it.physicalHeight == now.physicalHeight
        }
        val pick = (if (max) same.maxByOrNull { it.refreshRate }
                    else same.minByOrNull { abs(it.refreshRate - 60f) }) ?: return 0.0
        val attrs = window.attributes
        if (attrs.preferredDisplayModeId != pick.modeId) {
            attrs.preferredDisplayModeId = pick.modeId
            window.attributes = attrs
        }
        return pick.refreshRate.toDouble()
    }
}
