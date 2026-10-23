package me.tryfitos.app

import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.PermissionController
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `FlutterFragmentActivity`, not `FlutterActivity`, and the health permission
 * request goes through a registered launcher (Phase 6.6 Gate 6 fix).
 *
 * Why: on Android 14+ `PermissionController.createRequestPermissionResultContract()`
 * delegates to `ActivityResultContracts.RequestMultiplePermissions`, whose
 * intent carries the sentinel action
 * `androidx.activity.result.contract.action.REQUEST_PERMISSIONS`. No activity
 * on the device resolves it: `ActivityResultRegistry` recognises that action
 * and calls `ActivityCompat.requestPermissions` instead of starting an
 * activity. Building that intent by hand and calling `startActivityForResult`
 * therefore threw `ActivityNotFoundException` and killed the process the
 * moment "Connect" was tapped on a Samsung S24. Only a `ComponentActivity`
 * (which `FlutterFragmentActivity` is, via `FragmentActivity`) can register
 * the launcher that dispatches it correctly — on every API level.
 */
class MainActivity : FlutterFragmentActivity() {
    private var healthConnect: HealthConnectChannel? = null

    /**
     * Registered as a field, i.e. before the activity is CREATED, which is
     * what `registerForActivityResult` requires. The result set the contract
     * reports is only a hint; the channel re-reads what Health Connect
     * actually grants.
     */
    private val healthPermissionLauncher: ActivityResultLauncher<Set<String>> =
        registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) { granted ->
            healthConnect?.onPermissionResult(granted)
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Phase 6.5: the Health Connect read channel (owner D1).
        val channel = HealthConnectChannel(this, healthPermissionLauncher)
        healthConnect = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HealthConnectChannel.NAME)
            .setMethodCallHandler(channel)
        // The phone's IANA time zone for the server's day boundaries (§9.1);
        // Dart alone only knows an abbreviation such as "IST". Beta 3.2: and
        // the app icon (AppIcons).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitos/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "timeZone" -> result.success(java.util.TimeZone.getDefault().id)
                    // Beta 3.2 (ADR-027 amendment): the launcher icon.
                    "appIcon" -> result.success(AppIcons.current(this))
                    "setAppIcon" -> {
                        val name = call.arguments as? String
                        if (name == null || name !in AppIcons.NAMES) {
                            result.error("bad-icon", "Unknown app icon: $name", null)
                        } else {
                            AppIcons.choose(this, name)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        healthConnect?.dispose()
        healthConnect = null
        super.onDestroy()
    }
}
