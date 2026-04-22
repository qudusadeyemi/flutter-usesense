import Flutter
import Foundation
import UseSenseSDK

/// Adapter from LiveSenseV4Delegate to FlutterResult for the v4 method channel.
/// Phase 1 ticket F-1.
final class V4FlutterBridgeDelegate: NSObject, LiveSenseV4Delegate {
    private let result: FlutterResult
    private var strong: LiveSenseV4Session?
    private var didFinish = false

    init(result: @escaping FlutterResult) {
        self.result = result
    }

    func retain(_ session: LiveSenseV4Session) { strong = session }

    func sessionDidComplete(verdict: V4Verdict) {
        if didFinish { return }
        didFinish = true
        let body: [String: Any?] = [
            "session_id": verdict.sessionId,
            "verdict": verdict.verdict.rawValue,
            "confidence": verdict.confidence.rawValue,
            "assurance_level_achieved": verdict.assuranceLevelAchieved,
            "capture_channel": "flutter",
            "match_sense_embedding_id": verdict.matchSenseEmbeddingId,
            "timestamp": verdict.timestamp
        ]
        result(body.compactMapValues { $0 })
        strong = nil
    }

    func sessionDidFail(error: Error) {
        if didFinish { return }
        didFinish = true
        result(FlutterError(code: "V4_FAILED",
                            message: error.localizedDescription,
                            details: nil))
        strong = nil
    }

    func sessionPhaseDidChange(phase: LiveSenseV4Phase) {
        // No event sink for phase updates in Phase 1.
    }
}
