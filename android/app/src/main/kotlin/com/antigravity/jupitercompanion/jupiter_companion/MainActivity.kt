package com.antigravity.jupitercompanion.jupiter_companion

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import com.antigravity.jupitercompanion.jupiter_companion.services.RideTrackingForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.antigravity.jupitercompanion/ride_tracking"
    private val EVENT_CHANNEL = "com.antigravity.jupitercompanion/location_events"

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup MethodChannel for Service Controls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    val rideId = call.argument<String>("rideId") ?: "ride_${System.currentTimeMillis()}"
                    val minTimeMs = call.argument<Number>("minTimeMs")?.toLong() ?: 1000L
                    val minDistanceM = call.argument<Number>("minDistanceM")?.toFloat() ?: 1.0f

                    val intent = Intent(this, RideTrackingForegroundService::class.java).apply {
                        action = RideTrackingForegroundService.ACTION_START
                        putExtra(RideTrackingForegroundService.EXTRA_RIDE_ID, rideId)
                        putExtra(RideTrackingForegroundService.EXTRA_MIN_TIME_MS, minTimeMs)
                        putExtra(RideTrackingForegroundService.EXTRA_MIN_DISTANCE_M, minDistanceM)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                "pauseTracking" -> {
                    val intent = Intent(this, RideTrackingForegroundService::class.java).apply {
                        action = RideTrackingForegroundService.ACTION_PAUSE
                    }
                    startService(intent)
                    result.success(true)
                }

                "resumeTracking" -> {
                    val intent = Intent(this, RideTrackingForegroundService::class.java).apply {
                        action = RideTrackingForegroundService.ACTION_RESUME
                    }
                    startService(intent)
                    result.success(true)
                }

                "stopTracking" -> {
                    val intent = Intent(this, RideTrackingForegroundService::class.java).apply {
                        action = RideTrackingForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }

                "getTrackingStatus" -> {
                    val status = mapOf(
                        "isRunning" to RideTrackingForegroundService.isServiceRunning,
                        "isPaused" to RideTrackingForegroundService.isPaused,
                        "currentRideId" to RideTrackingForegroundService.currentRideId
                    )
                    result.success(status)
                }

                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pm?.isIgnoringBatteryOptimizations(packageName) ?: false
                    } else {
                        true
                    }
                    result.success(isIgnoring)
                }

                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            // Fallback to general settings
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                            result.success(false)
                        }
                    } else {
                        result.success(true)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // Setup EventChannel for Location Streaming from Foreground Service
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    RideTrackingForegroundService.locationCallback = { locData ->
                        runOnUiThread {
                            eventSink?.success(
                                mapOf(
                                    "latitude" to locData.latitude,
                                    "longitude" to locData.longitude,
                                    "altitude" to locData.altitude,
                                    "accuracy" to locData.accuracy,
                                    "speed" to locData.speed,
                                    "bearing" to locData.bearing,
                                    "timestamp" to locData.timestamp,
                                    "isPaused" to locData.isPaused
                                )
                            )
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    RideTrackingForegroundService.locationCallback = null
                }
            }
        )
    }
}
