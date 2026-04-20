package com.example.quickdeliver

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "quickdeliver/android_tracking",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    val arguments = call.arguments as? Map<*, *>
                    if (arguments == null) {
                        result.error("invalid_args", "Tracking arguments were missing.", null)
                        return@setMethodCallHandler
                    }
                    val hardError = NativeRiderTrackingService.validateHardRequirements(applicationContext)
                    if (hardError != null) {
                        result.error("tracking_unavailable", hardError, null)
                        return@setMethodCallHandler
                    }
                    val startArguments = mapOf(
                        "supabase_url" to arguments["supabaseUrl"] as? String,
                        "supabase_anon_key" to arguments["supabaseAnonKey"] as? String,
                        "access_token" to arguments["accessToken"] as? String,
                        "refresh_token" to arguments["refreshToken"] as? String,
                        "rider_id" to arguments["riderId"] as? String,
                        "rider_name" to arguments["riderName"] as? String,
                        "order_id" to arguments["orderId"] as? String,
                    )
                    NativeRiderTrackingService.startTracking(applicationContext, startArguments)
                    result.success(NativeRiderTrackingService.statusMap(applicationContext))
                }

                "stopTracking" -> {
                    val markInactive = call.argument<Boolean>("markInactive") ?: false
                    NativeRiderTrackingService.stopTracking(applicationContext, markInactive)
                    result.success(NativeRiderTrackingService.statusMap(applicationContext))
                }

                "getStatus" -> {
                    result.success(NativeRiderTrackingService.statusMap(applicationContext))
                }

                "getDiagnostics" -> {
                    result.success(NativeRiderTrackingService.diagnosticsMap(applicationContext))
                }

                else -> result.notImplemented()
            }
        }
    }
}
