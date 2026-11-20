import Flutter
import UIKit
import UseSenseSDK

/// `UseSenseView` on iOS: a platform view hosting the SDK's
/// `UseSenseViewController` as a child of the Flutter view controller. The
/// controller (not the bare SwiftUI `UseSenseView`) is what seeds the
/// code-set branding over the dashboard's, so the embedded capture looks the
/// same as the full-screen one.
final class UseSenseViewFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "com.usesense.flutter/view"

    private let messenger: FlutterBinaryMessenger
    private weak var plugin: UseSenseFlutterPlugin?

    init(messenger: FlutterBinaryMessenger, plugin: UseSenseFlutterPlugin) {
        self.messenger = messenger
        self.plugin = plugin
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        UseSenseEmbeddedView(
            frame: frame,
            viewId: viewId,
            args: args as? [String: Any] ?? [:],
            messenger: messenger,
            plugin: plugin
        )
    }
}

final class UseSenseEmbeddedView: NSObject, FlutterPlatformView {
    private let container: EmbedContainerView
    private let channel: FlutterMethodChannel
    private var controller: UseSenseViewController?
    private var settled = false
    private var disposed = false
    /// Dart has set its handler ("ready"); until then a result waits here.
    private var ready = false
    private var pending: (String, Any?)?

    init(frame: CGRect, viewId: Int64, args: [String: Any], messenger: FlutterBinaryMessenger, plugin: UseSenseFlutterPlugin?) {
        container = EmbedContainerView(frame: frame)
        channel = FlutterMethodChannel(name: "com.usesense.flutter/view_\(viewId)", binaryMessenger: messenger)
        super.init()

        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "ready":
                self?.markReady()
                result(nil)
            case "back":
                // iOS has no system back for the capture: it has its own close
                // button, and Dart lets the route pop (which disposes this view).
                result(nil)
            case "dispose":
                self?.teardown()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        guard let session = Self.makeSession(args: args, plugin: plugin, fail: { [weak self] code, message in
            self?.send("onError", ["code": code, "message": message, "details": nil])
        }) else { return }

        let vc = UseSenseViewController(session: session) { [weak self] result in
            DispatchQueue.main.async { self?.deliver(result) }
        }
        controller = vc
        container.onWindow = { [weak self] in self?.embedIfNeeded() }
    }

    func view() -> UIView { container }

    deinit {
        // Runs when Flutter disposes the platform view.
        let vc = controller
        DispatchQueue.main.async { Self.unembed(vc) }
    }

    // MARK: - Session

    private static func makeSession(
        args: [String: Any],
        plugin: UseSenseFlutterPlugin?,
        fail: (String, String) -> Void
    ) -> UseSenseSession? {
        let sessionType = (args["sessionType"] as? String).flatMap(nativeSessionType)
        if (args["kind"] as? String) == "token" {
            let token = (args["clientToken"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else {
                fail("invalid_config", "clientToken must not be blank.")
                return nil
            }
            let client = plugin?.tokenClient() ?? UseSense(config: UseSenseConfig(apiKey: ""))
            return client.createSessionWithToken(clientToken: token, sessionType: sessionType ?? .authentication)
        }
        guard let client = plugin?.apiKeyClient else {
            fail("sdk_not_initialized", "UseSense SDK is not initialized. Call initialize() first.")
            return nil
        }
        guard let type = sessionType else {
            fail("invalid_config", "sessionType is required.")
            return nil
        }
        let metadata = (args["metadata"] as? [String: String])?.mapValues { AnyCodableValue.string($0) }
        return client.startVerification(request: VerificationRequest(
            sessionType: type,
            externalUserId: args["externalUserId"] as? String,
            identityId: args["identityId"] as? String,
            metadata: metadata
        ))
    }

    private static func nativeSessionType(_ name: String) -> SessionType? {
        switch name {
        case "enrollment": return .enrollment
        case "authentication": return .authentication
        case "liveness": return .liveness
        default: return nil
        }
    }

    // MARK: - Containment

    private func embedIfNeeded() {
        guard !disposed, let vc = controller, vc.parent == nil, container.window != nil,
              let parent = container.nearestViewController() else { return }
        parent.addChild(vc)
        vc.view.frame = container.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(vc.view)
        vc.didMove(toParent: parent)
    }

    private static func unembed(_ vc: UIViewController?) {
        guard let vc = vc, vc.parent != nil else { return }
        vc.willMove(toParent: nil)
        vc.view.removeFromSuperview()
        vc.removeFromParent()
    }

    private func teardown() {
        guard !disposed else { return }
        disposed = true
        channel.setMethodCallHandler(nil)
        Self.unembed(controller)
        controller = nil
    }

    // MARK: - Results

    private func deliver(_ result: Result<RedactedDecisionObject, UseSenseError>) {
        switch result {
        case .success(let decision):
            let r = UseSenseFlutterPlugin.pigeonResult(decision)
            send("onResult", [
                "sessionId": r.sessionId,
                "sessionType": r.sessionType as Any,
                "identityId": r.identityId as Any,
                "decision": r.decision,
                "timestamp": r.timestamp,
            ])
        case .failure(let error) where error.code == .userCancelled:
            send("onCancelled", nil)
        case .failure(let error):
            send("onError", [
                "code": UseSenseFlutterPlugin.errorCode(error),
                "message": error.message,
                "details": error.details as Any,
            ])
        }
    }

    /// Once, after Dart is listening, and never after dispose.
    private func send(_ method: String, _ payload: Any?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.disposed, !self.settled else { return }
            self.settled = true
            if self.ready {
                self.channel.invokeMethod(method, arguments: payload)
            } else {
                self.pending = (method, payload)
            }
        }
    }

    private func markReady() {
        ready = true
        if let (method, payload) = pending, !disposed {
            pending = nil
            channel.invokeMethod(method, arguments: payload)
        }
    }
}

/// Embeds the capture controller once the platform view is in a window, so
/// the nearest view controller (the Flutter one) can be its parent.
final class EmbedContainerView: UIView {
    var onWindow: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { onWindow?() }
    }

    func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}
