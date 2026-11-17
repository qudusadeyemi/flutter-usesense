import Flutter
import Foundation
import UseSenseSDK

/// MethodChannel bridge for the headless silent device check
/// (`UseSense.deviceCheck(config:)`). Channel: `com.usesense.flutter/device_check`.
///
/// `start` and `finish` carry a Dart-side `handle` plus the check's config; the
/// first call for a handle creates the native `UseSenseDeviceCheck`, later calls
/// reuse it (start and finish must run on the same instance). `dispose` forgets it.
///
/// Results always resolve (never a FlutterError) as
/// `{ok, phase, error?: {code, message, retryable, serverCode, httpStatus}}`.
final class UseSenseDeviceCheckBridge: NSObject {
    private var checks: [String: UseSenseDeviceCheck] = [:]
    private let lock = NSLock()

    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start", "finish":
            run(call: call, result: result)
        case "dispose":
            if let args = call.arguments as? [String: Any], let handle = args["handle"] as? String {
                lock.lock()
                checks.removeValue(forKey: handle)
                lock.unlock()
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func disposeAll() {
        lock.lock()
        checks.removeAll()
        lock.unlock()
    }

    private func run(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let phase = call.method
        guard let args = call.arguments as? [String: Any],
              let handle = args["handle"] as? String, !handle.isEmpty else {
            result(Self.failure(phase: phase, code: "invalid_config", message: "The device check is not set up (no handle)"))
            return
        }
        lock.lock()
        let check: UseSenseDeviceCheck
        if let existing = checks[handle] {
            check = existing
        } else {
            let base = (args["apiBaseUrl"] as? String).flatMap(URL.init(string:)) ?? DeviceCheckConfig.defaultBaseURL
            let timeout = (args["timeoutMs"] as? NSNumber).map { $0.doubleValue / 1000 } ?? DeviceCheckConfig.defaultRequestTimeout
            check = UseSense.deviceCheck(config: DeviceCheckConfig(
                deviceCheckId: (args["deviceCheckId"] as? String) ?? "",
                token: (args["token"] as? String) ?? "",
                nonce: (args["nonce"] as? String) ?? "",
                baseURL: base,
                requestTimeout: timeout
            ))
            checks[handle] = check
        }
        lock.unlock()

        let done: (DeviceCheckResult) -> Void = { r in result(Self.toMap(r, phase: phase)) }
        if phase == "start" {
            check.start(completion: done)
        } else {
            check.finish(completion: done)
        }
    }

    private static func toMap(_ r: DeviceCheckResult, phase: String) -> [String: Any?] {
        switch r {
        case .received(let p):
            return ["ok": true, "phase": p.rawValue]
        case .failed(let e):
            return [
                "ok": false,
                "phase": phase,
                "error": [
                    "code": e.code.rawValue,
                    "message": e.message,
                    "retryable": e.isRetryable,
                    "serverCode": e.serverCode as Any?,
                    "httpStatus": e.httpStatus as Any?,
                ] as [String: Any?],
            ]
        }
    }

    private static func failure(phase: String, code: String, message: String) -> [String: Any?] {
        ["ok": false, "phase": phase, "error": ["code": code, "message": message, "retryable": false] as [String: Any?]]
    }
}
