import SwiftUI

@main
struct ScreenshotRouterApp: App {
    @StateObject private var model = RouterModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("ScreenshotRouter", systemImage: "camera.viewfinder") {
            Button(model.text("영역 캡처…", "Capture Area…")) { model.captureArea() }
            Button(model.text("설정…", "Settings…")) { model.showSettings() }
            Divider()
            Button(model.text("종료", "Quit")) { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}
