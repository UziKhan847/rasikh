package com.uzikhan.rasikh

import android.app.ActivityManager
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
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
    // A turn from one side straight to the other (180°) leaves the window's
    // size as it was, so Flutter hears nothing of it: the display listener
    // tells it ("rotation" with the new value).
    private var displayChannel: MethodChannel? = null
    private var lastRotation = -1
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {
            val r = currentRotation()
            if (r != lastRotation) {
                lastRotation = r
                displayChannel?.invokeMethod("rotation", r)
            }
        }
    }

    private fun currentRotation(): Int {
        val d: Display? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display
            else @Suppress("DEPRECATION") windowManager.defaultDisplay
        return d?.rotation ?: 0
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qiraah/display")
        channel.setMethodCallHandler { call, result ->
            if (call.method == "rotation") {
                result.success(currentRotation())
            } else if (call.method == "ramMb") {
                val info = ActivityManager.MemoryInfo()
                (getSystemService(ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(info)
                result.success((info.totalMem / (1024 * 1024)).toInt())
            } else {
                result.notImplemented()
            }
        }
        displayChannel = channel
        lastRotation = currentRotation()
        (getSystemService(DISPLAY_SERVICE) as DisplayManager)
            .registerDisplayListener(displayListener, Handler(Looper.getMainLooper()))
    }

    override fun onDestroy() {
        (getSystemService(DISPLAY_SERVICE) as DisplayManager)
            .unregisterDisplayListener(displayListener)
        displayChannel = null
        super.onDestroy()
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
