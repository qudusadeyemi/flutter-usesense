package com.usesense.flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.usesense.sdk.UseSense
import com.usesense.sdk.devicecheck.DeviceCheck
import com.usesense.sdk.devicecheck.DeviceCheckConfig
import com.usesense.sdk.devicecheck.DeviceCheckResult
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel bridge for the headless silent device check
 * (`UseSense.deviceCheck`). Channel: `com.usesense.flutter/device_check`.
 *
 * Methods `start` and `finish` carry a Dart-side `handle` plus the check's
 * config; the first call for a handle creates the native [DeviceCheck], later
 * calls reuse it (start and finish must run on the same instance). `dispose`
 * cancels and forgets it.
 *
 * Results always arrive through `result.success` as
 * `{ok, phase, error?: {code, message, retryable, serverCode, httpStatus}}`:
 * the native check never throws and neither does this bridge.
 */
class UseSenseDeviceCheckBridge(private val context: () -> Context?) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val checks = mutableMapOf<String, DeviceCheck>()

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start", "finish" -> run(call, result)
            "dispose" -> {
                call.argument<String>("handle")?.let { handle ->
                    synchronized(checks) { checks.remove(handle) }?.cancel()
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun disposeAll() {
        val all = synchronized(checks) { checks.values.toList().also { checks.clear() } }
        all.forEach { it.cancel() }
    }

    private fun run(call: MethodCall, result: MethodChannel.Result) {
        val phase = call.method
        val handle = call.argument<String>("handle")
        val ctx = context()
        if (handle.isNullOrBlank() || ctx == null) {
            result.success(failure(phase, "invalid_config", "The device check is not set up (no handle or context)"))
            return
        }
        val check = synchronized(checks) {
            checks.getOrPut(handle) {
                val timeout = (call.argument<Number>("timeoutMs"))?.toLong()
                UseSense.deviceCheck(
                    ctx,
                    DeviceCheckConfig(
                        deviceCheckId = call.argument<String>("deviceCheckId") ?: "",
                        token = call.argument<String>("token") ?: "",
                        nonce = call.argument<String>("nonce") ?: "",
                        baseUrl = call.argument<String>("apiBaseUrl"),
                        timeoutMs = timeout ?: DeviceCheckConfig.DEFAULT_TIMEOUT_MS,
                    ),
                )
            }
        }
        val callback = { r: DeviceCheckResult -> mainHandler.post { result.success(toMap(r)) } }
        if (phase == "start") check.start { callback(it) } else check.finish { callback(it) }
    }

    private fun toMap(r: DeviceCheckResult): Map<String, Any?> =
        when (r) {
            is DeviceCheckResult.Sent -> mapOf("ok" to true, "phase" to r.phase.wire)
            is DeviceCheckResult.Failed ->
                mapOf(
                    "ok" to false,
                    "phase" to r.phase.wire,
                    "error" to
                        mapOf(
                            "code" to r.error.code.wire,
                            "message" to r.error.message,
                            "retryable" to r.error.isRetryable,
                            "serverCode" to r.error.serverCode,
                            "httpStatus" to r.error.httpStatus,
                        ),
                )
        }

    private fun failure(phase: String, code: String, message: String): Map<String, Any?> =
        mapOf(
            "ok" to false,
            "phase" to phase,
            "error" to mapOf("code" to code, "message" to message, "retryable" to false),
        )
}
