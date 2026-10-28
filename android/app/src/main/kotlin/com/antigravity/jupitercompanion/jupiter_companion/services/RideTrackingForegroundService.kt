package com.antigravity.jupitercompanion.jupiter_companion.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Binder
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.antigravity.jupitercompanion.jupiter_companion.MainActivity

/**
 * Native Android Foreground Service for continuous, resilient ride tracking.
 * Guarantees location updates continue when the phone screen is locked or app is in background.
 */
class RideTrackingForegroundService : Service(), LocationListener {

    companion object {
        const val CHANNEL_ID = "jupiter_companion_ride_tracking"
        const val CHANNEL_NAME = "Ride Tracking Active"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "com.antigravity.jupitercompanion.ACTION_START"
        const val ACTION_PAUSE = "com.antigravity.jupitercompanion.ACTION_PAUSE"
        const val ACTION_RESUME = "com.antigravity.jupitercompanion.ACTION_RESUME"
        const val ACTION_STOP = "com.antigravity.jupitercompanion.ACTION_STOP"

        const val EXTRA_RIDE_ID = "extra_ride_id"
        const val EXTRA_MIN_TIME_MS = "extra_min_time_ms"
        const val EXTRA_MIN_DISTANCE_M = "extra_min_distance_m"

        var isServiceRunning = false
            private set
        var isPaused = false
            private set
        var currentRideId: String? = null
            private set

        // Callback listener for Flutter EventChannel
        var locationCallback: ((LocationData) -> Unit)? = null
    }

    data class LocationData(
        val latitude: Double,
        val longitude: Double,
        val altitude: Double,
        val accuracy: Float,
        val speed: Float,
        val bearing: Float,
        val timestamp: Long,
        val isPaused: Boolean
    )

    private var locationManager: LocationManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var totalPointsCollected = 0
    private var lastRecordedSpeed = 0f

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START

        when (action) {
            ACTION_START -> {
                val rideId = intent?.getStringExtra(EXTRA_RIDE_ID) ?: "ride_${System.currentTimeMillis()}"
                val minTimeMs = intent?.getLongExtra(EXTRA_MIN_TIME_MS, 1000L) ?: 1000L
                val minDistanceM = intent?.getFloatExtra(EXTRA_MIN_DISTANCE_M, 1.0f) ?: 1.0f
                startTracking(rideId, minTimeMs, minDistanceM)
            }
            ACTION_PAUSE -> {
                pauseTracking()
            }
            ACTION_RESUME -> {
                resumeTracking()
            }
            ACTION_STOP -> {
                stopTracking()
                stopSelf()
            }
        }

        return START_STICKY
    }

    private fun startTracking(rideId: String, minTimeMs: Long, minDistanceM: Float) {
        currentRideId = rideId
        isServiceRunning = true
        isPaused = false
        totalPointsCollected = 0

        val notification = buildNotification("Ride in progress...", "GPS tracking active (Screen lock protected)")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        registerLocationUpdates(minTimeMs, minDistanceM)
    }

    private fun pauseTracking() {
        isPaused = true
        updateNotification("Ride paused", "Tracking paused. Tap to resume.")
    }

    private fun resumeTracking() {
        isPaused = false
        updateNotification("Ride in progress...", "GPS tracking active: $totalPointsCollected points recorded")
    }

    private fun stopTracking() {
        isServiceRunning = false
        isPaused = false
        currentRideId = null
        unregisterLocationUpdates()
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun registerLocationUpdates(minTimeMs: Long, minDistanceM: Float) {
        try {
            locationManager?.let { lm ->
                if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, minTimeMs, minDistanceM, this)
                }
                if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, minTimeMs, minDistanceM, this)
                }
            }
        } catch (e: SecurityException) {
            // Permission revoked or not granted
            e.printStackTrace()
        }
    }

    private fun unregisterLocationUpdates() {
        try {
            locationManager?.removeUpdates(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onLocationChanged(location: Location) {
        // Discard paused points from continuous movement tracking
        totalPointsCollected++
        lastRecordedSpeed = if (location.hasSpeed()) location.speed * 3.6f else 0f // km/h

        val data = LocationData(
            latitude = location.latitude,
            longitude = location.longitude,
            altitude = if (location.hasAltitude()) location.altitude else 0.0,
            accuracy = if (location.hasAccuracy()) location.accuracy else 999f,
            speed = if (location.hasSpeed()) location.speed else 0f,
            bearing = if (location.hasBearing()) location.bearing else 0f,
            timestamp = location.time,
            isPaused = isPaused
        )

        locationCallback?.invoke(data)

        if (!isPaused && totalPointsCollected % 10 == 0) {
            updateNotification(
                "Ride in progress • %.0f km/h".format(lastRecordedSpeed),
                "$totalPointsCollected GPS points recorded • Active session"
            )
        }
    }

    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live status while recording TVS Jupiter scooter rides in the background"
                enableLights(false)
                enableVibration(false)
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, text: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        launchIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(title: String, text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.notify(NOTIFICATION_ID, buildNotification(title, text))
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "JupiterCompanion::RideTrackingWakeLock"
            )?.apply {
                setReferenceCounted(false)
                acquire(4 * 60 * 60 * 1000L) // 4 hours max safety timeout
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        stopTracking()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

