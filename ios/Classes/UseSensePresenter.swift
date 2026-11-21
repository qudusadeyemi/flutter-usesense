import UIKit

/// Finds the view controller the plugin presents the capture from.
///
/// Flutter apps created with `flutter create` since 3.38 use the UIScene
/// lifecycle (`SceneDelegate: FlutterSceneDelegate`). Their window belongs to
/// the scene, so `UIApplication.shared.delegate?.window` is nil and a lookup
/// through it fails every start with "Root view controller is not available."
/// (found on an iPhone with 2.11.0, 2026-11-21). Look the window up through
/// the connected scenes first, then fall back to the app delegate's window for
/// apps still on the AppDelegate lifecycle, and present from the top-most
/// controller so a modal route on screen does not block the presentation.
enum UseSensePresenter {
    static func topViewController() -> UIViewController? {
        var current = rootViewController()
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }

    private static func rootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        // Prefer the scene in the foreground, then any scene.
        let ordered = scenes.filter { $0.activationState == .foregroundActive } + scenes
        for scene in ordered {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
               let root = window.rootViewController {
                return root
            }
        }
        if let window = UIApplication.shared.delegate?.window, let root = window?.rootViewController {
            return root
        }
        return nil
    }
}
