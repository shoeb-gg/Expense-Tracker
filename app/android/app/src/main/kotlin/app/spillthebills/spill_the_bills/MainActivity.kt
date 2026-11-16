package app.spillthebills.spill_the_bills

import android.app.UiModeManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NIGHT_MODE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != SET_NIGHT_MODE) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val nightMode = when (call.arguments as? String) {
                    "dark" -> UiModeManager.MODE_NIGHT_YES
                    "light" -> UiModeManager.MODE_NIGHT_NO
                    // Follows the phone: platformBrightness keeps tracking it.
                    "system" -> UiModeManager.MODE_NIGHT_AUTO
                    else -> null
                }
                if (nightMode == null) {
                    result.error("bad_mode", "Unknown night mode", null)
                    return@setMethodCallHandler
                }
                // The app's own night mode exists from Android 12 (API 31).
                // Below that the launch screen keeps following the phone.
                // The system keeps the value, so the next cold start's launch
                // screen (values or values-night) matches the app's choice.
                // The activity handles uiMode itself (see the manifest), so
                // this does not restart it.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    getSystemService(UiModeManager::class.java)
                        .setApplicationNightMode(nightMode)
                }
                result.success(null)
            }
    }

    private companion object {
        const val NIGHT_MODE_CHANNEL = "app.spillthebills/night_mode"
        const val SET_NIGHT_MODE = "setNightMode"
    }
}
