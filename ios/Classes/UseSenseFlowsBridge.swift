import Flutter
import UIKit
import UseSenseSDK

/// MethodChannel bridge for the Flows runner. Sits alongside the existing
/// Pigeon-generated Sessions surface, sidestepping pigeon regen. Channel
/// name: `com.usesense.flutter/flows`. Single inbound method: `runFlow`.
///
/// On success: the Future resolves with a Map containing flowRunId/state/outcome.
/// On failure: a FlutterError with the FlowError code as `code`.
final class UseSenseFlowsBridge: NSObject {
    private weak var registrar: FlutterPluginRegistrar?

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    /// Handle a single MethodChannel invocation. Dispatched on the main
    /// thread by Flutter so the SDK's UIKit presentation works directly.
    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "runFlow":
            guard let args = call.arguments as? [String: Any],
                  let flowRunId = args["flowRunId"] as? String,
                  let sdkToken = args["sdkToken"] as? String else {
                result(FlutterError(code: "unknown", message: "flowRunId and sdkToken are required", details: nil))
                return
            }
            let apiBaseURLString = (args["apiBaseUrl"] as? String) ?? "https://api.usesense.ai"
            guard let apiBaseURL = URL(string: apiBaseURLString) else {
                result(FlutterError(code: "unknown", message: "Invalid apiBaseUrl", details: nil))
                return
            }
            guard let presenter = Self.topViewController() else {
                result(FlutterError(code: "unknown", message: "No view controller to present from", details: nil))
                return
            }

            UseSenseFlows.run(
                flowRunId: flowRunId,
                sdkToken: sdkToken,
                apiBaseURL: apiBaseURL,
                from: presenter,
            ) { runResult in
                switch runResult {
                case .success(let r):
                    result([
                        "flowRunId": r.flowRunId,
                        "state": Self.stateWire(r.state),
                        "outcome": r.outcome.map(Self.outcomeWire) as Any,
                    ])
                case .failure(let e):
                    result(FlutterError(code: e.code.rawValue, message: e.message, details: nil))
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Helpers

    private static func stateWire(_ state: FlowRunState) -> String {
        switch state {
        case .pending: return "pending"
        case .inProgress: return "in_progress"
        case .stalled: return "stalled"
        case .awaitingReview: return "awaiting_review"
        case .completed: return "completed"
        case .errored: return "errored"
        case .abandoned: return "abandoned"
        case .cancelled: return "cancelled"
        }
    }

    private static func outcomeWire(_ outcome: FlowOutcome) -> String {
        switch outcome {
        case .approve: return "APPROVE"
        case .reject: return "REJECT"
        case .manualReview: return "MANUAL_REVIEW"
        }
    }

    /// Find the top-most view controller to present from. Mirrors the
    /// pattern the V4 bridge uses; works across UIKit + SceneDelegate apps
    /// and falls back gracefully to `keyWindow.rootViewController`.
    private static func topViewController() -> UIViewController? {
        var root: UIViewController?
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
                    root = keyWindow.rootViewController
                    break
                }
            }
        }
        if root == nil {
            root = UIApplication.shared.keyWindow?.rootViewController
        }
        var current = root
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }
}
