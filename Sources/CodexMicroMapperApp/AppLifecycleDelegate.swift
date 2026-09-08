import AppKit
import Foundation

extension Notification.Name {
    static let codexMicroMapperDidOpenSettings = Notification.Name(
        "CodexMicroMapperDidOpenSettings"
    )
    static let codexMicroMapperWillTerminate = Notification.Name(
        "CodexMicroMapperWillTerminate"
    )
}

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            Self.presentMainWindow(requestOnboarding: false)
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        Self.presentMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .codexMicroMapperWillTerminate, object: nil)
    }

    static func presentMainWindow(requestOnboarding: Bool = true) {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: {
            $0.title == "Codex Micro Mapper" && $0.canBecomeKey
        }) {
            window.makeKeyAndOrderFront(nil)
        }
        if requestOnboarding {
            NotificationCenter.default.post(name: .codexMicroMapperDidOpenSettings, object: nil)
        }
    }
}
