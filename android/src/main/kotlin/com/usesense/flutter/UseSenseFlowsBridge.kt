package com.usesense.flutter

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.usesense.sdk.flows.FlowError
import com.usesense.sdk.flows.FlowOutcome
import com.usesense.sdk.flows.FlowRunResult
import com.usesense.sdk.flows.FlowRunState
import com.usesense.sdk.flows.FlowsCallback
import com.usesense.sdk.flows.UseSenseFlows
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel bridge for the Flows runner. Sits alongside the existing
 * Pigeon-generated Sessions surface, sidestepping pigeon regen. Channel
 * name: `com.usesense.flutter/flows`. Single inbound method: `runFlow`.
 *
 * On success the result is a Map<String, Any?> with flowRunId/state/outcome;
 * on failure the result is a FlutterError with the FlowError code as `code`.
 */
class UseSenseFlowsBridge {
    private val mainHandler = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: MethodChannel.Result, activity: Activity?) {
        when (call.method) {
            "runFlow" -> {
                val flowRunId = call.argument<String>("flowRunId")
                val sdkToken = call.argument<String>("sdkToken")
                val apiBaseUrl = call.argument<String>("apiBaseUrl") ?: "https://api.usesense.ai"
                if (flowRunId == null || sdkToken == null) {
                    result.error("unknown", "flowRunId and sdkToken are required", null)
                    return
                }
                val act = activity ?: run {
                    result.error("unknown", "No current activity to launch from", null)
                    return
                }

                val callback = object : FlowsCallback {
                    override fun onResult(r: FlowRunResult) {
                        mainHandler.post {
                            result.success(
                                mapOf(
                                    "flowRunId" to r.flowRunId,
                                    "state" to stateWire(r.state),
                                    "outcome" to r.outcome?.let { outcomeWire(it) },
                                ),
                            )
                        }
                    }

                    override fun onError(error: FlowError) {
                        mainHandler.post {
                            result.error(error.code.wire, error.message, null)
                        }
                    }
                }

                UseSenseFlows.run(
                    activity = act,
                    flowRunId = flowRunId,
                    sdkToken = sdkToken,
                    callback = callback,
                    apiBaseUrl = apiBaseUrl,
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun stateWire(state: FlowRunState): String = state.wire

    private fun outcomeWire(outcome: FlowOutcome): String = outcome.wire
}
