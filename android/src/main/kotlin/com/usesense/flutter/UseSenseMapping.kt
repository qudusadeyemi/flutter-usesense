package com.usesense.flutter

import com.usesense.sdk.SessionType
import com.usesense.sdk.UseSenseError
import com.usesense.sdk.UseSenseResult

/**
 * Native to pigeon / Flutter mapping shared by the start methods and the
 * embedded [UseSenseViewFactory], so a result or an error reads the same in
 * Dart whichever surface produced it.
 */
internal object UseSenseMapping {

    /** Server codes for a rejected client token (exchange-token 404 / 410 / 409 / 401). */
    private val CLIENT_TOKEN_CODES = setOf("token_not_found", "token_expired", "token_already_used", "invalid_token")

    fun sessionType(type: PigeonSessionType): SessionType = when (type) {
        PigeonSessionType.ENROLLMENT -> SessionType.ENROLLMENT
        PigeonSessionType.AUTHENTICATION -> SessionType.AUTHENTICATION
        PigeonSessionType.LIVENESS -> SessionType.LIVENESS
    }

    /** The Dart `SessionType.name` ("enrollment", ...) as the native type, or null. */
    fun sessionType(name: String?): SessionType? = when (name) {
        "enrollment" -> SessionType.ENROLLMENT
        "authentication" -> SessionType.AUTHENTICATION
        "liveness" -> SessionType.LIVENESS
        else -> null
    }

    fun result(result: UseSenseResult): PigeonUseSenseResult = PigeonUseSenseResult(
        sessionId = result.sessionId,
        sessionType = result.sessionType,
        identityId = result.identityId,
        decision = result.decision,
        timestamp = result.timestamp,
    )

    fun resultMap(result: UseSenseResult): Map<String, Any?> = mapOf(
        "sessionId" to result.sessionId,
        "sessionType" to result.sessionType,
        "identityId" to result.identityId,
        "decision" to result.decision,
        "timestamp" to result.timestamp,
    )

    /** The Flutter error code for [error] (the strings `UseSenseError.codeFromString` reads). */
    fun errorCode(error: UseSenseError): String {
        error.serverCode?.lowercase()?.let { if (it in CLIENT_TOKEN_CODES) return it }
        return when (error.code) {
            UseSenseError.CAMERA_UNAVAILABLE -> "camera_unavailable"
            UseSenseError.CAMERA_PERMISSION_DENIED -> "camera_permission_denied"
            UseSenseError.MICROPHONE_PERMISSION_DENIED -> "microphone_permission_denied"
            UseSenseError.NETWORK_ERROR -> "network_error"
            UseSenseError.NETWORK_TIMEOUT -> "network_timeout"
            UseSenseError.SESSION_EXPIRED -> "session_expired"
            UseSenseError.UPLOAD_FAILED -> "upload_failed"
            UseSenseError.CAPTURE_FAILED -> "capture_failed"
            UseSenseError.ENCODING_FAILED -> "encoding_failed"
            UseSenseError.INVALID_CONFIG -> "invalid_config"
            UseSenseError.QUOTA_EXCEEDED -> "quota_exceeded"
            else -> "sdk_error"
        }
    }

    /** String-valued details, as Dart reads them (`Map<String, String>`). */
    fun errorDetails(error: UseSenseError): Map<String, String>? =
        error.details?.mapValues { (_, v) -> v.toString() }

    fun error(error: UseSenseError): FlutterError =
        FlutterError(errorCode(error), error.message, errorDetails(error))

    fun cancelled(): FlutterError =
        FlutterError("session_cancelled", "User cancelled the verification session.", null)
}
