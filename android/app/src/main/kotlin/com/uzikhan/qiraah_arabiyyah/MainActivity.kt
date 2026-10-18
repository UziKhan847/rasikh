package com.uzikhan.qiraah_arabiyyah

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

// Android leaves many phones (Samsung especially) at 60 Hz unless the app asks
// for more. On start, ask for the screen's fastest mode at its resolution.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferFastestMode()
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
