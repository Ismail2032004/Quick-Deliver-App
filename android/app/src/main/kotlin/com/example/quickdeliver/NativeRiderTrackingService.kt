package com.example.quickdeliver

import android.Manifest
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import kotlin.math.abs

class NativeRiderTrackingService : Service() {
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var notificationManager: NotificationManager
    private val executor = Executors.newSingleThreadExecutor()

    private var locationCallback: LocationCallback? = null
    private var currentConfig: TrackingConfig? = null
    private var lastSentAtMillis: Long = 0L
    private var lastSentLatitude: Double? = null
    private var lastSentLongitude: Double? = null
    private var latestLatitude: Double? = null
    private var latestLongitude: Double? = null

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureNotificationChannel()
        currentConfig = loadConfig(this)
        lastSentLatitude = prefs(this).getString(KEY_LAST_LATITUDE, null)?.toDoubleOrNull()
        lastSentLongitude = prefs(this).getString(KEY_LAST_LONGITUDE, null)?.toDoubleOrNull()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> handleStart(intent)
            ACTION_STOP -> handleStop(markInactive = intent.getBooleanExtra(EXTRA_MARK_INACTIVE, false))
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        removeLocationUpdates()
        executor.shutdown()
        super.onDestroy()
    }

    private fun handleStart(intent: Intent) {
        val hardError = validateHardRequirements(this)
        if (hardError != null) {
            saveStatus(this, isActive = false, lastError = hardError)
            stopSelf()
            return
        }

        val config = TrackingConfig.fromIntent(intent) ?: loadConfig(this)
        if (config == null) {
            saveStatus(this, isActive = false, lastError = "Native tracking configuration is missing.")
            stopSelf()
            return
        }

        currentConfig = config
        saveConfig(this, config)
        saveStatus(
            this,
            isActive = true,
            orderId = config.orderId,
            lastError = null,
            statusMessage = guidanceMessage(this),
        )

        startForeground(NOTIFICATION_ID, buildNotification(config.orderId, "Sharing live rider location for ${config.orderId}."))
        requestLocationUpdates(config)
    }

    private fun handleStop(markInactive: Boolean) {
        val config = currentConfig ?: loadConfig(this)
        removeLocationUpdates()
        if (markInactive && config != null && latestLatitude != null && latestLongitude != null) {
            executor.execute {
                uploadLocation(
                    config = config,
                    latitude = latestLatitude!!,
                    longitude = latestLongitude!!,
                    isActive = false,
                    force = true,
                )
            }
        }
        saveStatus(this, isActive = false, orderId = null, lastError = null, statusMessage = null)
        clearConfig(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun requestLocationUpdates(config: TrackingConfig) {
        removeLocationUpdates()

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10_000L)
            .setMinUpdateDistanceMeters(15f)
            .setWaitForAccurateLocation(false)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val location = result.lastLocation ?: return
                latestLatitude = location.latitude
                latestLongitude = location.longitude
                updateNotification(
                    config.orderId,
                    "Latest point ${location.latitude.formatCoord()}, ${location.longitude.formatCoord()}",
                )
                executor.execute {
                    uploadLocation(
                        config = config,
                        latitude = location.latitude,
                        longitude = location.longitude,
                        isActive = true,
                        force = false,
                    )
                }
            }
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            saveStatus(this, isActive = false, orderId = config.orderId, lastError = "Fine location permission is missing.")
            stopSelf()
            return
        }

        fusedLocationClient.requestLocationUpdates(request, locationCallback!!, Looper.getMainLooper())
        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
            if (location != null) {
                latestLatitude = location.latitude
                latestLongitude = location.longitude
                executor.execute {
                    uploadLocation(
                        config = config,
                        latitude = location.latitude,
                        longitude = location.longitude,
                        isActive = true,
                        force = true,
                    )
                }
            }
        }
    }

    private fun removeLocationUpdates() {
        locationCallback?.let { fusedLocationClient.removeLocationUpdates(it) }
        locationCallback = null
    }

    private fun uploadLocation(
        config: TrackingConfig,
        latitude: Double,
        longitude: Double,
        isActive: Boolean,
        force: Boolean,
    ) {
        if (!force && shouldThrottle(latitude, longitude)) {
            return
        }

        val body = JSONObject()
            .put("rider_id", config.riderId)
            .put("rider_name", config.riderName)
            .put("latitude", latitude)
            .put("longitude", longitude)
            .put("order_id", config.orderId)
            .put("is_active", isActive)
            .put("updated_at", isoNow())
            .toString()

        val initial = performUpsert(config, body, config.accessToken)
        val success = if (initial == HttpURLConnection.HTTP_UNAUTHORIZED && !config.refreshToken.isNullOrBlank()) {
            val refreshed = refreshAccessToken(config)
            if (refreshed != null) {
                saveConfig(this, refreshed)
                currentConfig = refreshed
                performUpsert(refreshed, body, refreshed.accessToken) in 200..299
            } else {
                false
            }
        } else {
            initial in 200..299
        }

        if (success) {
            lastSentAtMillis = System.currentTimeMillis()
            lastSentLatitude = latitude
            lastSentLongitude = longitude
            prefs(this).edit()
                .putString(KEY_LAST_LATITUDE, latitude.toString())
                .putString(KEY_LAST_LONGITUDE, longitude.toString())
                .apply()
            saveStatus(
                this,
                isActive = true,
                orderId = config.orderId,
                lastError = null,
                statusMessage = guidanceMessage(this) ?: "Native Android tracking is active.",
            )
        } else {
            saveStatus(
                this,
                isActive = true,
                orderId = config.orderId,
                lastError = "Native rider location update failed. Tracking will retry on the next location fix.",
                statusMessage = guidanceMessage(this),
            )
        }
    }

    private fun performUpsert(
        config: TrackingConfig,
        jsonBody: String,
        accessToken: String,
    ): Int {
        val url = URL("${config.supabaseUrl}/rest/v1/rider_locations?on_conflict=rider_id")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 10_000
            readTimeout = 10_000
            setRequestProperty("apikey", config.supabaseAnonKey)
            setRequestProperty("Authorization", "Bearer $accessToken")
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Prefer", "resolution=merge-duplicates,return=minimal")
        }

        return try {
            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(jsonBody)
            }
            connection.responseCode
        } finally {
            runCatching {
                val stream = if (connection.responseCode >= 400) connection.errorStream else connection.inputStream
                stream?.bufferedReader()?.use { it.readText() }
            }
            connection.disconnect()
        }
    }

    private fun refreshAccessToken(config: TrackingConfig): TrackingConfig? {
        val refreshToken = config.refreshToken ?: return null
        val url = URL("${config.supabaseUrl}/auth/v1/token?grant_type=refresh_token")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 10_000
            readTimeout = 10_000
            setRequestProperty("apikey", config.supabaseAnonKey)
            setRequestProperty("Content-Type", "application/json")
        }
        return try {
            val body = JSONObject().put("refresh_token", refreshToken).toString()
            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(body)
            }
            if (connection.responseCode !in 200..299) {
                null
            } else {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                config.copy(
                    accessToken = json.optString("access_token", config.accessToken),
                    refreshToken = json.optString("refresh_token", refreshToken),
                )
            }
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }

    private fun shouldThrottle(latitude: Double, longitude: Double): Boolean {
        val previousLatitude = lastSentLatitude ?: return false
        val previousLongitude = lastSentLongitude ?: return false
        val secondsSinceLastSend = (System.currentTimeMillis() - lastSentAtMillis) / 1000
        if (secondsSinceLastSend >= 12) {
            return false
        }
        val movedLat = abs(previousLatitude - latitude)
        val movedLng = abs(previousLongitude - longitude)
        return movedLat < 0.00025 && movedLng < 0.00025
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "QuickDeliver Rider Tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Ongoing rider tracking while an active delivery is in progress"
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun buildNotification(orderId: String, contentText: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("QuickDeliver rider tracking")
            .setContentText(contentText)
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "Live rider tracking is active for $orderId. Keep this notification available for the strongest Android background behavior.",
                ),
            )
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun updateNotification(orderId: String, contentText: String) {
        notificationManager.notify(NOTIFICATION_ID, buildNotification(orderId, contentText))
    }

    companion object {
        private const val TAG = "NativeRiderTracking"
        private const val PREFS_NAME = "quickdeliver_native_tracking"
        private const val CHANNEL_ID = "quickdeliver_native_rider_tracking"
        private const val NOTIFICATION_ID = 43110
        private const val ACTION_START = "com.example.quickdeliver.action.START_NATIVE_TRACKING"
        private const val ACTION_STOP = "com.example.quickdeliver.action.STOP_NATIVE_TRACKING"
        private const val EXTRA_MARK_INACTIVE = "mark_inactive"

        private const val KEY_IS_ACTIVE = "is_active"
        private const val KEY_ORDER_ID = "order_id"
        private const val KEY_LAST_ERROR = "last_error"
        private const val KEY_STATUS_MESSAGE = "status_message"
        private const val KEY_SUPABASE_URL = "supabase_url"
        private const val KEY_SUPABASE_ANON_KEY = "supabase_anon_key"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_RIDER_ID = "rider_id"
        private const val KEY_RIDER_NAME = "rider_name"
        private const val KEY_LAST_LATITUDE = "last_latitude"
        private const val KEY_LAST_LONGITUDE = "last_longitude"

        fun buildStartIntent(context: Context, arguments: Map<String, Any?>): Intent {
            return Intent(context, NativeRiderTrackingService::class.java).apply {
                action = ACTION_START
                putExtra(KEY_SUPABASE_URL, arguments[KEY_SUPABASE_URL] as? String)
                putExtra(KEY_SUPABASE_ANON_KEY, arguments[KEY_SUPABASE_ANON_KEY] as? String)
                putExtra(KEY_ACCESS_TOKEN, arguments[KEY_ACCESS_TOKEN] as? String)
                putExtra(KEY_REFRESH_TOKEN, arguments[KEY_REFRESH_TOKEN] as? String)
                putExtra(KEY_RIDER_ID, arguments[KEY_RIDER_ID] as? String)
                putExtra(KEY_RIDER_NAME, arguments[KEY_RIDER_NAME] as? String)
                putExtra(KEY_ORDER_ID, arguments[KEY_ORDER_ID] as? String)
            }
        }

        fun buildStopIntent(context: Context, markInactive: Boolean): Intent {
            return Intent(context, NativeRiderTrackingService::class.java).apply {
                action = ACTION_STOP
                putExtra(EXTRA_MARK_INACTIVE, markInactive)
            }
        }

        fun startTracking(context: Context, arguments: Map<String, Any?>) {
            saveStatus(
                context,
                isActive = true,
                orderId = arguments["order_id"] as? String,
                lastError = null,
                statusMessage = guidanceMessage(context),
            )
            val intent = buildStartIntent(context, arguments)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stopTracking(context: Context, markInactive: Boolean) {
            saveStatus(
                context,
                isActive = false,
                orderId = null,
                lastError = null,
                statusMessage = null,
            )
            val intent = buildStopIntent(context, markInactive)
            if (isServiceRunning(context)) {
                runCatching {
                    context.startService(intent)
                }.onFailure { error ->
                    Log.w(TAG, "Unable to deliver stop command to native tracking service.", error)
                    clearConfig(context)
                    cancelTrackingNotification(context)
                    context.stopService(Intent(context, NativeRiderTrackingService::class.java))
                }
                return
            }
            clearConfig(context)
            cancelTrackingNotification(context)
        }

        fun statusMap(context: Context): Map<String, Any?> {
            val prefs = prefs(context)
            return mapOf(
                "isActive" to prefs.getBoolean(KEY_IS_ACTIVE, false),
                "isServiceRunning" to isServiceRunning(context),
                "orderId" to prefs.getString(KEY_ORDER_ID, null),
                "lastError" to prefs.getString(KEY_LAST_ERROR, null),
                "statusMessage" to prefs.getString(KEY_STATUS_MESSAGE, null),
                "fineLocationGranted" to hasFineLocationPermission(context),
                "backgroundLocationGranted" to hasBackgroundLocationPermission(context),
                "notificationsGranted" to notificationsGranted(context),
                "gpsEnabled" to gpsEnabled(context),
                "batteryOptimizationActive" to batteryOptimizationActive(context),
            )
        }

        fun diagnosticsMap(context: Context): Map<String, Any?> = statusMap(context)

        fun validateHardRequirements(context: Context): String? {
            if (!gpsEnabled(context)) {
                return "Location services are turned off. Enable GPS/location services before starting native rider tracking."
            }
            if (!hasFineLocationPermission(context)) {
                return "Fine location permission is required before native rider tracking can start."
            }
            return null
        }

        fun guidanceMessage(context: Context): String? {
            if (!hasBackgroundLocationPermission(context)) {
                return "For stronger Android background tracking, allow location access all the time in system settings."
            }
            if (!notificationsGranted(context)) {
                return "Allow notifications so Android can keep the foreground-service tracking notification visible."
            }
            if (batteryOptimizationActive(context)) {
                return "Battery optimization is still active and may limit long-running Android tracking on some devices."
            }
            return "Native Android foreground-service tracking is active."
        }

        private fun hasFineLocationPermission(context: Context): Boolean {
            return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        }

        private fun hasBackgroundLocationPermission(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                return true
            }
            return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        }

        private fun notificationsGranted(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                return true
            }
            return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        }

        private fun gpsEnabled(context: Context): Boolean {
            val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            return manager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true ||
                manager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true
        }

        private fun batteryOptimizationActive(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                return false
            }
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            return !powerManager.isIgnoringBatteryOptimizations(context.packageName)
        }

        @Suppress("DEPRECATION")
        private fun isServiceRunning(context: Context): Boolean {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val running = manager?.getRunningServices(Int.MAX_VALUE) ?: return false
            return running.any { it.service.className == NativeRiderTrackingService::class.java.name }
        }

        private fun saveConfig(context: Context, config: TrackingConfig) {
            prefs(context).edit()
                .putString(KEY_SUPABASE_URL, config.supabaseUrl)
                .putString(KEY_SUPABASE_ANON_KEY, config.supabaseAnonKey)
                .putString(KEY_ACCESS_TOKEN, config.accessToken)
                .putString(KEY_REFRESH_TOKEN, config.refreshToken)
                .putString(KEY_RIDER_ID, config.riderId)
                .putString(KEY_RIDER_NAME, config.riderName)
                .putString(KEY_ORDER_ID, config.orderId)
                .apply()
        }

        private fun clearConfig(context: Context) {
            prefs(context).edit()
                .remove(KEY_SUPABASE_URL)
                .remove(KEY_SUPABASE_ANON_KEY)
                .remove(KEY_ACCESS_TOKEN)
                .remove(KEY_REFRESH_TOKEN)
                .remove(KEY_RIDER_ID)
                .remove(KEY_RIDER_NAME)
                .remove(KEY_ORDER_ID)
                .remove(KEY_LAST_LATITUDE)
                .remove(KEY_LAST_LONGITUDE)
                .apply()
        }

        private fun cancelTrackingNotification(context: Context) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancel(NOTIFICATION_ID)
        }

        private fun loadConfig(context: Context): TrackingConfig? {
            val prefs = prefs(context)
            val supabaseUrl = prefs.getString(KEY_SUPABASE_URL, null) ?: return null
            val supabaseAnonKey = prefs.getString(KEY_SUPABASE_ANON_KEY, null) ?: return null
            val accessToken = prefs.getString(KEY_ACCESS_TOKEN, null) ?: return null
            val riderId = prefs.getString(KEY_RIDER_ID, null) ?: return null
            val riderName = prefs.getString(KEY_RIDER_NAME, null) ?: return null
            val orderId = prefs.getString(KEY_ORDER_ID, null) ?: return null
            return TrackingConfig(
                supabaseUrl = supabaseUrl,
                supabaseAnonKey = supabaseAnonKey,
                accessToken = accessToken,
                refreshToken = prefs.getString(KEY_REFRESH_TOKEN, null),
                riderId = riderId,
                riderName = riderName,
                orderId = orderId,
            )
        }

        private fun saveStatus(
            context: Context,
            isActive: Boolean,
            orderId: String? = null,
            lastError: String? = null,
            statusMessage: String? = null,
        ) {
            prefs(context).edit()
                .putBoolean(KEY_IS_ACTIVE, isActive)
                .putString(KEY_ORDER_ID, orderId)
                .putString(KEY_LAST_ERROR, lastError)
                .putString(KEY_STATUS_MESSAGE, statusMessage)
                .apply()
        }

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        private fun isoNow(): String {
            val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            formatter.timeZone = TimeZone.getTimeZone("UTC")
            return formatter.format(Date())
        }
    }
}

private data class TrackingConfig(
    val supabaseUrl: String,
    val supabaseAnonKey: String,
    val accessToken: String,
    val refreshToken: String?,
    val riderId: String,
    val riderName: String,
    val orderId: String,
) {
    companion object {
        fun fromIntent(intent: Intent): TrackingConfig? {
            val supabaseUrl = intent.getStringExtra("supabase_url") ?: return null
            val supabaseAnonKey = intent.getStringExtra("supabase_anon_key") ?: return null
            val accessToken = intent.getStringExtra("access_token") ?: return null
            val riderId = intent.getStringExtra("rider_id") ?: return null
            val riderName = intent.getStringExtra("rider_name") ?: return null
            val orderId = intent.getStringExtra("order_id") ?: return null
            return TrackingConfig(
                supabaseUrl = supabaseUrl,
                supabaseAnonKey = supabaseAnonKey,
                accessToken = accessToken,
                refreshToken = intent.getStringExtra("refresh_token"),
                riderId = riderId,
                riderName = riderName,
                orderId = orderId,
            )
        }
    }
}

private fun Double.formatCoord(): String = String.format(Locale.US, "%.4f", this)
