package com.usesense.flutter

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.usesense.sdk.*

class UseSensePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private var eventUnsubscribe: (() -> Unit)? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, "com.usesense/method")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.usesense/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                subscribeToNativeEvents()
            }

            override fun onCancel(arguments: Any?) {
                eventUnsubscribe?.invoke()
                eventUnsubscribe = null
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventUnsubscribe?.invoke()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> handleInitialize(call, result)
            "startVerification" -> handleStartVerification(call, result)
            "isInitialized" -> result.success(UseSense.isInitialized)
            "reset" -> {
                eventUnsubscribe?.invoke()
                eventUnsubscribe = null
                UseSense.reset()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleInitialize(call: MethodCall, result: Result) {
        val apiKey = call.argument<String>("apiKey")
        if (apiKey.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "apiKey is required", null)
            return
        }

        val ctx = applicationContext
        if (ctx == null) {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }

        val brandingMap = call.argument<Map<String, Any?>>("branding")
        val branding = if (brandingMap != null) {
            BrandingConfig(
                logoUrl = brandingMap["logoUrl"] as? String,
                primaryColor = (brandingMap["primaryColor"] as? String) ?: "#4F63F5",
                buttonRadius = (brandingMap["buttonRadius"] as? Int) ?: 12,
                fontFamily = brandingMap["fontFamily"] as? String,
            )
        } else null

        val environment = when (call.argument<String>("environment")) {
            "sandbox" -> UseSenseEnvironment.SANDBOX
            "production" -> UseSenseEnvironment.PRODUCTION
            else -> UseSenseEnvironment.AUTO
        }

        val config = UseSenseConfig(
            apiKey = apiKey,
            environment = environment,
            baseUrl = call.argument<String>("baseUrl") ?: UseSenseConfig.DEFAULT_BASE_URL,
            gatewayKey = call.argument<String>("gatewayKey"),
            branding = branding,
            googleCloudProjectNumber = call.argument<Number>("googleCloudProjectNumber")?.toLong()
                ?: UseSenseConfig.DEFAULT_GOOGLE_CLOUD_PROJECT_NUMBER,
        )

        UseSense.initialize(ctx, config)
        result.success(null)
    }

    private fun handleStartVerification(call: MethodCall, result: Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        val sessionType = when (call.argument<String>("sessionType")) {
            "authentication" -> SessionType.AUTHENTICATION
            else -> SessionType.ENROLLMENT
        }

        @Suppress("UNCHECKED_CAST")
        val metadata = call.argument<Map<String, Any>>("metadata")

        val request = VerificationRequest(
            sessionType = sessionType,
            externalUserId = call.argument<String>("externalUserId"),
            identityId = call.argument<String>("identityId"),
            metadata = metadata,
        )

        UseSense.startVerification(act, request, object : UseSenseCallback {
            override fun onSuccess(useSenseResult: UseSenseResult) {
                act.runOnUiThread {
                    result.success(mapOf(
                        "sessionId" to useSenseResult.sessionId,
                        "sessionType" to useSenseResult.sessionType,
                        "identityId" to useSenseResult.identityId,
                        "decision" to useSenseResult.decision,
                        "timestamp" to useSenseResult.timestamp,
                        "isApproved" to useSenseResult.isApproved,
                        "isRejected" to useSenseResult.isRejected,
                        "isPendingReview" to useSenseResult.isPendingReview,
                    ))
                }
            }

            override fun onError(error: UseSenseError) {
                act.runOnUiThread {
                    result.error(
                        error.code.toString(),
                        error.message,
                        mapOf(
                            "code" to error.code,
                            "serverCode" to error.serverCode,
                            "message" to error.message,
                            "isRetryable" to error.isRetryable,
                        ),
                    )
                }
            }

            override fun onCancelled() {
                act.runOnUiThread {
                    result.error("CANCELLED", "Verification was cancelled by the user", null)
                }
            }
        })
    }

    private fun subscribeToNativeEvents() {
        eventUnsubscribe?.invoke()
        eventUnsubscribe = UseSense.onEvent { event ->
            activity?.runOnUiThread {
                eventSink?.success(mapOf(
                    "type" to event.type.name,
                    "timestamp" to event.timestamp,
                    "data" to event.data,
                ))
            }
        }
    }
}
