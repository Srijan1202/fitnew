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
    private var widgetChannel: MethodChannel? = null
    private var widgetLaunch: String? = null

    private fun widgetLink(intent: android.content.Intent?): String? {
        val data = intent?.data ?: return null
        return if (data.scheme == "fitos" && data.host == "widget") data.toString() else null
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        val link = widgetLink(intent) ?: return
        val channel = widgetChannel
        if (channel == null) widgetLaunch = link else channel.invokeMethod("open", link)
    }

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
        // Beta 5.0: a home-screen widget's tap (fitos://widget/<target>): the
        // one FITOS opened from is taken once; later ones are sent as they come.
        widgetLaunch = widgetLink(intent)
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitos/widget")
            .apply {
                setMethodCallHandler { call, result ->
                    if (call.method == "takeLaunch") {
                        result.success(widgetLaunch)
                        widgetLaunch = null
                    } else {
                        result.notImplemented()
                    }
                }
            }
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
                            AppIcons.request(this, name)
                            result.success(null)
                        }
                    }
                    // Beta 4.0 (ADR-038): a run must keep recording with the
                    // screen off, which battery optimisation can prevent.
                    "batteryUnrestricted" -> {
                        val power = getSystemService(POWER_SERVICE) as android.os.PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(packageName))
                    }
                    // Beta 5.0: the home-screen widgets redraw from the new snapshot.
                    "updateWidgets" -> {
                        HomeWidgets.updateAll(applicationContext)
                        result.success(null)
                    }
                    // Beta 4.9: the 6-hourly Galaxy Watch import (WatchImportWorker).
                    "scheduleWatchImport" -> {
                        WatchImportWorker.schedule(applicationContext, call.arguments == true)
                        result.success(null)
                    }
                    "openBatterySettings" -> {
                        // The app's own page: Battery → Unrestricted is one tap there.
                        val intent = android.content.Intent(
                            android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            android.net.Uri.fromParts("package", packageName, null),
                        )
                        startActivity(intent)
                        result.success(null)
                    }
                    // Beta 4.1 (updates plan, U2): FITOS installs its own APK.
                    "canInstallApks" -> result.success(packageManager.canRequestPackageInstalls())
                    "openInstallSettings" -> {
                        // FITOS's own "Install unknown apps" switch.
                        val intent = android.content.Intent(
                            android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            android.net.Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.arguments as? String
                        val file = path?.let { java.io.File(it) }
                        // Only a file in the cache's updates/ folder (update_paths.xml).
                        val updates = java.io.File(cacheDir, "updates").canonicalPath
                        if (file == null || !file.isFile || file.canonicalFile.parent != updates) {
                            result.error("bad-apk", "Not a downloaded update: $path", null)
                        } else {
                            val uri = androidx.core.content.FileProvider.getUriForFile(
                                this,
                                "$packageName.updates",
                                file,
                            )
                            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW)
                                .setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(
                                    android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        android.content.Intent.FLAG_ACTIVITY_NEW_TASK,
                                )
                            startActivity(intent)
                            result.success(null)
                        }
                    }
                    // Beta 4.1.1: the share picture's map, route included.
                    "routeSnapshot" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        if (args == null) {
                            result.error("bad-route", "No arguments", null)
                        } else {
                            RouteSnapshot.take(this, args, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Beta 4.1.1 (owner: "app crash on app icon change"): a chosen icon is
    // switched once the user leaves FITOS (Home, Recents) or backs out of
    // it, never while it is in front: Samsung's launcher closes the app when
    // the entry it was opened from is switched off. Not on the camera, the
    // share sheet or a settings page FITOS opened itself.
    // Android also calls onUserLeaveHint when FITOS opens another app's
    // screen itself; every such start passes through here first.
    private var openingOwnIntent = false

    @Deprecated("Overridden only to see FITOS's own starts; behaviour unchanged.")
    override fun startActivityForResult(
        intent: android.content.Intent,
        requestCode: Int,
        options: android.os.Bundle?,
    ) {
        openingOwnIntent = true
        @Suppress("DEPRECATION")
        super.startActivityForResult(intent, requestCode, options)
    }

    override fun onResume() {
        super.onResume()
        openingOwnIntent = false
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (!openingOwnIntent) AppIcons.applyPending(this)
    }

    override fun onDestroy() {
        healthConnect?.dispose()
        healthConnect = null
        if (isFinishing) AppIcons.applyPending(this)
        super.onDestroy()
    }
}
