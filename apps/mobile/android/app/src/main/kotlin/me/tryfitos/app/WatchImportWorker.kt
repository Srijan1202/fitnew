package me.tryfitos.app

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Beta 4.9 (owner): Galaxy Watch runs come in with FITOS closed. Every 6
 * hours (any network, battery not low) this starts the app's Dart without a
 * screen at `watchImportMain` (main.dart), which imports through the same
 * code as Running opening, and waits for its "done" — at most 4 minutes.
 *
 * Health Connect allows the read only with READ_HEALTH_DATA_IN_BACKGROUND;
 * the Dart side schedules this only while the user's switch is on and that
 * permission is granted, and cancels it otherwise.
 */
class WatchImportWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    companion object {
        private const val NAME = "fitos.watchImport"

        fun schedule(context: Context, on: Boolean) {
            val work = WorkManager.getInstance(context)
            if (!on) {
                work.cancelUniqueWork(NAME)
                return
            }
            val request = PeriodicWorkRequestBuilder<WatchImportWorker>(6, TimeUnit.HOURS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .setRequiresBatteryNotLow(true)
                        .build(),
                )
                .build()
            // KEEP: turning the app on again does not restart the 6 hours.
            work.enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.Main) {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val engine = FlutterEngine(applicationContext)
        val health = HealthConnectChannel(applicationContext)
        val done = CompletableDeferred<Unit>()
        try {
            val messenger = engine.dartExecutor.binaryMessenger
            MethodChannel(messenger, HealthConnectChannel.NAME).setMethodCallHandler(health)
            MethodChannel(messenger, "fitos/background").setMethodCallHandler { call, result ->
                if (call.method == "done") {
                    result.success(null)
                    done.complete(Unit)
                } else {
                    result.notImplemented()
                }
            }
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "watchImportMain"),
            )
            withTimeoutOrNull(TimeUnit.MINUTES.toMillis(4)) { done.await() }
            Result.success()
        } catch (e: Exception) {
            Result.success() // tried again in 6 hours, or when Running opens
        } finally {
            health.dispose()
            engine.destroy()
        }
    }
}
