package com.example.fitos

import android.app.Activity
import android.content.Intent
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.aggregate.AggregateMetric
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Phase 6.5 (owner D1): the ONLY code that talks to Health Connect. Read
 * only. Every method takes explicit epoch-millisecond ranges computed on
 * the Dart side in the user's calendar; cumulative metrics go through
 * `aggregate()` so Health Connect de-duplicates across sources (its
 * documented behaviour — never summed from raw records here). Nothing is
 * logged: values cross the channel and nowhere else.
 */
class HealthConnectChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "fitos/health_connect"
        private const val REQUEST_PERMISSIONS = 0x4843 // "HC"

        /** Permission string ↔ the record class it reads. */
        private val READ_PERMISSIONS: Map<String, String> = mapOf(
            "steps" to "android.permission.health.READ_STEPS",
            "distance" to "android.permission.health.READ_DISTANCE",
            "activeCalories" to "android.permission.health.READ_ACTIVE_CALORIES_BURNED",
            "totalCalories" to "android.permission.health.READ_TOTAL_CALORIES_BURNED",
            "exercise" to "android.permission.health.READ_EXERCISE",
            "sleep" to "android.permission.health.READ_SLEEP",
            "restingHeartRate" to "android.permission.health.READ_RESTING_HEART_RATE",
            "weight" to "android.permission.health.READ_WEIGHT",
            "bodyFat" to "android.permission.health.READ_BODY_FAT",
            "bmr" to "android.permission.health.READ_BASAL_METABOLIC_RATE",
        )
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val permissionContract = PermissionController.createRequestPermissionResultContract()

    fun dispose() {
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkStatus" -> result.success(sdkStatus())
            "grantedPermissions" -> launch(result) { grantedPermissions() }
            "requestPermissions" -> requestPermissions(call, result)
            "aggregate" -> launch(result) { aggregate(call) }
            "latest" -> launch(result) { latest(call) }
            "exerciseSessions" -> launch(result) { exerciseSessions(call) }
            "openSettings" -> result.success(openSettings())
            else -> result.notImplemented()
        }
    }

    /* ----------------------------------------------------- availability -- */

    private fun sdkStatus(): String = when (HealthConnectClient.getSdkStatus(activity)) {
        HealthConnectClient.SDK_AVAILABLE -> "available"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "updateRequired"
        else -> "unavailable"
    }

    private fun client(): HealthConnectClient? =
        if (HealthConnectClient.getSdkStatus(activity) == HealthConnectClient.SDK_AVAILABLE) {
            HealthConnectClient.getOrCreate(activity)
        } else {
            null
        }

    /* ------------------------------------------------------- permissions -- */

    /** Metric keys whose READ permission is currently granted (re-read every time: revocable). */
    private suspend fun grantedPermissions(): List<String> {
        val c = client() ?: return emptyList()
        val granted = c.permissionController.getGrantedPermissions()
        return READ_PERMISSIONS.filterValues { it in granted }.keys.toList()
    }

    private fun requestPermissions(call: MethodCall, result: MethodChannel.Result) {
        if (client() == null) {
            result.success(emptyList<String>())
            return
        }
        if (pendingPermissionResult != null) {
            result.error("busy", "A permission request is already in progress.", null)
            return
        }
        val keys = call.argument<List<String>>("metrics") ?: emptyList()
        val permissions = keys.mapNotNull { READ_PERMISSIONS[it] }.toSet()
        if (permissions.isEmpty()) {
            result.success(emptyList<String>())
            return
        }
        pendingPermissionResult = result
        val intent = permissionContract.createIntent(activity, permissions)
        @Suppress("DEPRECATION")
        activity.startActivityForResult(intent, REQUEST_PERMISSIONS)
    }

    /** MainActivity forwards its activity result here. Returns true when handled. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PERMISSIONS) return false
        val pending = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        // The contract's answer is unreliable on some OEM builds; the source
        // of truth is what Health Connect now says is granted.
        scope.launch {
            try {
                permissionContract.parseResult(resultCode, data)
                pending.success(grantedPermissions())
            } catch (e: Exception) {
                pending.error("permissions", e.message, null)
            }
        }
        return true
    }

    private fun openSettings(): Boolean = try {
        activity.startActivity(Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS))
        true
    } catch (e: Exception) {
        false
    }

    /* ------------------------------------------------------------- reads -- */

    private fun range(call: MethodCall): TimeRangeFilter {
        val start = call.argument<Number>("startMillis")!!.toLong()
        val end = call.argument<Number>("endMillis")!!.toLong()
        return TimeRangeFilter.between(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end))
    }

    /**
     * Totals over an explicit range: steps, distance (m), active and total
     * kcal, sleep minutes, resting heart rate (bpm, average). Absent keys
     * mean Health Connect had no data for that metric in the range — the
     * Dart side turns that into `noData`, never 0.
     */
    private suspend fun aggregate(call: MethodCall): Map<String, Any?> {
        val c = client() ?: throw IllegalStateException("unavailable")
        val keys = call.argument<List<String>>("metrics") ?: emptyList()
        val metrics = mutableSetOf<AggregateMetric<*>>()
        for (k in keys) {
            when (k) {
                "steps" -> metrics.add(StepsRecord.COUNT_TOTAL)
                "distance" -> metrics.add(DistanceRecord.DISTANCE_TOTAL)
                "activeCalories" -> metrics.add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
                "totalCalories" -> metrics.add(TotalCaloriesBurnedRecord.ENERGY_TOTAL)
                "sleep" -> metrics.add(SleepSessionRecord.SLEEP_DURATION_TOTAL)
                "restingHeartRate" -> metrics.add(RestingHeartRateRecord.BPM_AVG)
            }
        }
        if (metrics.isEmpty()) return emptyMap()
        val response = withContext(Dispatchers.IO) {
            c.aggregate(AggregateRequest(metrics = metrics, timeRangeFilter = range(call)))
        }
        val out = mutableMapOf<String, Any?>()
        response[StepsRecord.COUNT_TOTAL]?.let { out["steps"] = it }
        response[DistanceRecord.DISTANCE_TOTAL]?.let { out["distance"] = it.inMeters }
        response[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.let { out["activeCalories"] = it.inKilocalories }
        response[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.let { out["totalCalories"] = it.inKilocalories }
        response[SleepSessionRecord.SLEEP_DURATION_TOTAL]?.let { out["sleep"] = it.toMinutes() }
        response[RestingHeartRateRecord.BPM_AVG]?.let { out["restingHeartRate"] = it }
        out["sources"] = response.dataOrigins.map { it.packageName }
        return out
    }

    /** The most recent record of a point type in the range: value, when, source. */
    private suspend fun latest(call: MethodCall): Map<String, Any?>? {
        val c = client() ?: throw IllegalStateException("unavailable")
        val type = call.argument<String>("type")!!
        val filter = range(call)
        return withContext(Dispatchers.IO) {
            when (type) {
                "weight" -> c.readRecords(
                    ReadRecordsRequest(WeightRecord::class, filter, ascendingOrder = false, pageSize = 1),
                ).records.firstOrNull()?.let {
                    mapOf("value" to it.weight.inKilograms, "unit" to "kg", "time" to it.time.toEpochMilli(), "source" to it.metadata.dataOrigin.packageName)
                }
                "bodyFat" -> c.readRecords(
                    ReadRecordsRequest(BodyFatRecord::class, filter, ascendingOrder = false, pageSize = 1),
                ).records.firstOrNull()?.let {
                    mapOf("value" to it.percentage.value, "unit" to "%", "time" to it.time.toEpochMilli(), "source" to it.metadata.dataOrigin.packageName)
                }
                "bmr" -> c.readRecords(
                    ReadRecordsRequest(BasalMetabolicRateRecord::class, filter, ascendingOrder = false, pageSize = 1),
                ).records.firstOrNull()?.let {
                    mapOf("value" to it.basalMetabolicRate.inKilocaloriesPerDay, "unit" to "kcal/day", "time" to it.time.toEpochMilli(), "source" to it.metadata.dataOrigin.packageName)
                }
                "restingHeartRate" -> c.readRecords(
                    ReadRecordsRequest(RestingHeartRateRecord::class, filter, ascendingOrder = false, pageSize = 1),
                ).records.firstOrNull()?.let {
                    mapOf("value" to it.beatsPerMinute, "unit" to "bpm", "time" to it.time.toEpochMilli(), "source" to it.metadata.dataOrigin.packageName)
                }
                else -> null
            }
        }
    }

    /** Exercise sessions overlapping the range: start, end, type code, title, source. */
    private suspend fun exerciseSessions(call: MethodCall): List<Map<String, Any?>> {
        val c = client() ?: throw IllegalStateException("unavailable")
        val filter = range(call)
        return withContext(Dispatchers.IO) {
            c.readRecords(ReadRecordsRequest(ExerciseSessionRecord::class, filter)).records.map {
                mapOf(
                    "start" to it.startTime.toEpochMilli(),
                    "end" to it.endTime.toEpochMilli(),
                    "type" to it.exerciseType,
                    "title" to it.title,
                    "source" to it.metadata.dataOrigin.packageName,
                )
            }
        }
    }

    /* ------------------------------------------------------------ helpers -- */

    private fun launch(result: MethodChannel.Result, body: suspend () -> Any?) {
        scope.launch {
            try {
                result.success(body())
            } catch (e: SecurityException) {
                // A permission revoked since the last check: the Dart side
                // re-reads grants and shows "permission denied", never stale data.
                result.error("permissionDenied", e.message, null)
            } catch (e: IllegalStateException) {
                result.error("unavailable", e.message, null)
            } catch (e: Exception) {
                result.error("temporarilyUnavailable", e.javaClass.simpleName, null)
            }
        }
    }
}
