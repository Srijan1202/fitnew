package com.example.fitos

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var healthConnect: HealthConnectChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Phase 6.5: the Health Connect read channel (owner D1).
        val channel = HealthConnectChannel(this)
        healthConnect = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HealthConnectChannel.NAME)
            .setMethodCallHandler(channel)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (healthConnect?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        healthConnect?.dispose()
        healthConnect = null
        super.onDestroy()
    }
}
