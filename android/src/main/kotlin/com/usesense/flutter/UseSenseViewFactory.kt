package com.usesense.flutter

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.usesense.sdk.UseSenseCallback
import com.usesense.sdk.UseSenseError
import com.usesense.sdk.UseSenseResult
import com.usesense.sdk.VerificationRequest
import com.usesense.sdk.ui.UseSenseFragment
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * `UseSenseView` on Android: a platform view hosting the native
 * [UseSenseFragment] (the same capture Fragment the full-screen Activity
 * uses, so config, branding and copy from `initialize` apply, code over
 * dashboard).
 *
 * Requirements and lifecycle:
 * - The host must be a [FragmentActivity] (`FlutterFragmentActivity`), as for
 *   any Fragment. Otherwise the view reports `unsupported_activity`.
 * - Dart creates it with hybrid composition, so the container lives in the
 *   Activity's view hierarchy where the FragmentManager can find it.
 * - The Fragment is added when the container attaches and removed when Dart
 *   disposes the view. Results after dispose are dropped (the widget is gone).
 * - Dart owns back navigation (`PopScope`) and forwards it with `back`; the
 *   Fragment's own back callback (leave dialog, cancel) handles it.
 * - Camera and microphone permissions are requested by the Fragment.
 */
internal class UseSenseViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        UseSenseEmbeddedView(context, viewId, args as? Map<*, *> ?: emptyMap<String, Any?>(), messenger, activityProvider())

    companion object {
        const val VIEW_TYPE = "com.usesense.flutter/view"
        internal const val TAG_PREFIX = "usesense.flutter.view."

        /** Tags of the Fragments live views own; anything else with the prefix is stale. */
        internal val liveTags = mutableSetOf<String>()
    }
}

internal class UseSenseEmbeddedView(
    context: Context,
    viewId: Int,
    args: Map<*, *>,
    messenger: BinaryMessenger,
    activity: Activity?,
) : PlatformView {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "com.usesense.flutter/view_$viewId")
    private val tag = UseSenseViewFactory.TAG_PREFIX + viewId
    private val host = activity as? FragmentActivity
    private val container = FrameLayout(context).apply { id = View.generateViewId() }
    private var fragment: UseSenseFragment? = null
    private var disposed = false
    private var settled = false
    /** Dart has set its handler ("ready"); until then a result waits here. */
    private var ready = false
    private var pending: Pair<String, Any?>? = null

    private val attachListener = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(v: View) = attachFragment()
        override fun onViewDetachedFromWindow(v: View) = Unit
    }

    // Declared before init: start() hands it to the Fragment.
    private val callback = object : UseSenseCallback {
        override fun onSuccess(result: UseSenseResult) =
            send("onResult", UseSenseMapping.resultMap(result))

        override fun onError(error: UseSenseError) = send(
            "onError",
            mapOf(
                "code" to UseSenseMapping.errorCode(error),
                "message" to error.message,
                "details" to UseSenseMapping.errorDetails(error),
            ),
        )

        override fun onCancelled() = send("onCancelled", null)
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> {
                    ready = true
                    pending?.let { (method, payload) -> if (!disposed) channel.invokeMethod(method, payload) }
                    pending = null
                    result.success(null)
                }
                "dispose" -> result.success(null) // the engine calls dispose()
                "back" -> {
                    val f = fragment
                    val activity = host
                    // The Fragment registers its back callback with the
                    // view; while it is shown it is the topmost one.
                    if (!disposed && activity != null && f != null && f.isAdded && f.view != null) {
                        activity.onBackPressedDispatcher.onBackPressed()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        start(args)
    }

    private fun start(args: Map<*, *>) {
        if (host == null) {
            fail("unsupported_activity", "UseSenseView needs a FragmentActivity on Android: make MainActivity extend FlutterFragmentActivity.")
            return
        }
        val created = try {
            when (args["kind"]) {
                "token" -> UseSenseFragment.newInstanceWithToken(
                    (args["clientToken"] as? String).orEmpty().trim(),
                    UseSenseMapping.sessionType(args["sessionType"] as? String)
                        ?: com.usesense.sdk.SessionType.AUTHENTICATION,
                )
                else -> {
                    val type = UseSenseMapping.sessionType(args["sessionType"] as? String)
                        ?: return fail("invalid_config", "sessionType is required.")
                    @Suppress("UNCHECKED_CAST")
                    UseSenseFragment.newInstance(
                        VerificationRequest(
                            sessionType = type,
                            externalUserId = args["externalUserId"] as? String,
                            identityId = args["identityId"] as? String,
                            metadata = (args["metadata"] as? Map<String, Any>),
                        ),
                    )
                }
            }
        } catch (e: IllegalStateException) {
            // newInstance(request) needs initialize() (the API key).
            fail("sdk_not_initialized", e.message ?: "UseSense SDK is not initialized. Call initialize() first.")
            return
        }
        created.setCallback(callback)
        fragment = created
        UseSenseViewFactory.liveTags += tag
        container.addOnAttachStateChangeListener(attachListener)
        if (container.isAttachedToWindow) attachFragment()
    }

    private fun attachFragment() {
        val f = fragment ?: return
        val activity = host ?: return
        if (disposed || f.isAdded || activity.isFinishing || activity.isDestroyed) return
        val fm = activity.supportFragmentManager
        if (fm.isStateSaved) return
        // A Fragment restored after a configuration change or process death
        // belongs to a view that no longer exists: drop it.
        val stale = fm.fragments.filter { other ->
            other.tag?.startsWith(UseSenseViewFactory.TAG_PREFIX) == true && other.tag !in UseSenseViewFactory.liveTags
        }
        val tx = fm.beginTransaction()
        stale.forEach { tx.remove(it) }
        tx.replace(container.id, f, tag).commitNowAllowingStateLoss()
    }

    private fun fail(code: String, message: String) =
        send("onError", mapOf("code" to code, "message" to message, "details" to null))

    /** Once, on the main thread, after Dart is listening, and never after dispose. */
    private fun send(method: String, payload: Any?) {
        mainHandler.post {
            if (disposed || settled) return@post
            settled = true
            if (ready) channel.invokeMethod(method, payload) else pending = method to payload
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        if (disposed) return
        disposed = true
        channel.setMethodCallHandler(null)
        container.removeOnAttachStateChangeListener(attachListener)
        UseSenseViewFactory.liveTags -= tag
        val f = fragment
        fragment = null
        val activity = host ?: return
        if (f == null || !f.isAdded || activity.isDestroyed) return
        val fm = activity.supportFragmentManager
        // Removing ends the capture (camera, timers, upload). The SDK reports
        // a cancellation, which [send] drops: the widget has gone.
        if (fm.isStateSaved) {
            fm.beginTransaction().remove(f).commitAllowingStateLoss()
        } else {
            fm.beginTransaction().remove(f).commitNowAllowingStateLoss()
        }
    }
}
