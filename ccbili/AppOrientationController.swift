import SwiftUI
import UIKit

enum AppOrientationController {
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait
    static var preferredOrientation: UIInterfaceOrientation = .portrait

    @MainActor
    static func lock(
        _ orientations: UIInterfaceOrientationMask,
        preferred preferredOrientation: UIInterfaceOrientation = .portrait,
        scene: UIWindowScene? = nil
    ) {
        supportedOrientations = orientations
        self.preferredOrientation = preferredOrientation

        let activeScene = scene ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        activeScene?.windows.forEach { window in
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        if #available(iOS 16.0, *) {
            activeScene?.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        } else {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppOrientationController.supportedOrientations
    }
}

final class OrientationHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientationController.supportedOrientations
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        AppOrientationController.preferredOrientation
    }
}
