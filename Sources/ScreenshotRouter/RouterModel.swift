import SwiftUI
import AppKit
import Darwin
import ApplicationServices
import CoreGraphics

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean
    case english

    var id: Self { self }
}

enum RouterTab: Hashable {
    case setup
    case save
    case settings
}

@MainActor
final class RouterModel: ObservableObject {
    @Published var destinations: [Destination] = []
    @Published var pending: [PendingCapture] = [] {
        didSet {
            // Keep the preview and the editable name in step with the capture on screen.
            // Loading the preview once also keeps typing a name from re-reading the image on every keystroke.
            guard pending.first?.id != oldValue.first?.id else { return }
            preview = pending.first.flatMap { NSImage(contentsOf: $0.url) }
            fileName = defaultFileName
        }
    }
    @Published private(set) var preview: NSImage?
    @Published var fileName = ""
    @Published var selection: UUID?
    @Published var error: String?
    @Published var language: AppLanguage
    @Published var activeTab: RouterTab = .save
    @Published private(set) var accessibilityPermissionGranted: Bool
    @Published private(set) var screenRecordingPermissionGranted: Bool
    private var isCapturingArea = false
    let watchDirectory: URL
    let pendingDirectory: URL
    private let isolated: Bool
    private var watcher: CaptureWatcher?
    private let captureShortcut = CaptureShortcutMonitor()
    private var routerWindow: NSWindow?
    private let setupCompletedKey = "ScreenshotRouter.setupCompleted"

    init() {
        let environment = ProcessInfo.processInfo.environment
        isolated = environment["SCREENSHOT_ROUTER_DESTINATIONS"] != nil
        accessibilityPermissionGranted = AXIsProcessTrusted()
        screenRecordingPermissionGranted = CGPreflightScreenCaptureAccess()
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "ScreenshotRouter.language") ?? "")
            ?? (Locale.preferredLanguages.first?.hasPrefix("ko") == true ? .korean : .english)
        if let override = environment["SCREENSHOT_ROUTER_WATCH_DIR"] {
            watchDirectory = URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
        } else {
            let domain = UserDefaults.standard.persistentDomain(forName: "com.apple.screencapture")
            let path = (domain?["location"] as? String) ?? "~/Desktop"
            watchDirectory = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        pendingDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenshotRouter/Pending", isDirectory: true)
        if let override = environment["SCREENSHOT_ROUTER_DESTINATIONS"] {
            for path in override.split(separator: ":") {
                let destination = Destination(url: URL(fileURLWithPath: String(path), isDirectory: true))
                if !destinations.contains(where: { $0.path == destination.path }) { destinations.append(destination) }
            }
        } else if let data = UserDefaults.standard.data(forKey: "ScreenshotRouter.destinations") {
            do { destinations = try JSONDecoder().decode([Destination].self, from: data) }
            catch { self.error = "Could not load destinations: \(error.localizedDescription)" }
        }
        selection = destinations.first(where: \.writable)?.id
        do {
            try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
            pending = try CaptureFiles.recover(in: pendingDirectory)
            discardPending()
            let watcher = CaptureWatcher(directory: watchDirectory, pending: pendingDirectory)
            watcher.onCapture = { [weak self] url in
                guard let self, !self.pending.contains(where: { $0.url == url }) else { return }
                self.replacePending(with: url)
            }
            watcher.onError = { [weak self] message in
                self?.error = message
                self?.showRouter()
            }
            try watcher.start()
            self.watcher = watcher
        } catch { self.error = "Capture monitoring unavailable: \(error.localizedDescription)" }
        startCaptureShortcutIfAllowed()
        if needsInitialSetup || !pending.isEmpty {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.showRouter(tab: self.needsInitialSetup ? .setup : .save)
            }
        }
    }

    var selectedDestination: Destination? { destinations.first { $0.id == selection } }
    var defaultFileName: String { pending.first.map { CaptureFiles.defaultName(for: $0.discovered) } ?? "" }
    var canSave: Bool { !pending.isEmpty && selectedDestination?.writable == true }
    var needsInitialSetup: Bool { !isolated && !UserDefaults.standard.bool(forKey: setupCompletedKey) }
    func text(_ korean: String, _ english: String) -> String { language == .korean ? korean : english }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        persist()
    }

    func save(to destination: Destination? = nil) {
        guard let capture = pending.first, let destination = destination ?? selectedDestination else { return }
        selection = destination.id
        // End text editing first so input still being composed (such as a Hangul syllable) is part of the name.
        routerWindow?.makeFirstResponder(nil)
        do {
            let saved = try CaptureFiles.save(capture.url, to: destination.url, name: fileName, date: capture.discovered)
            watcher?.ignore(saved)
            let parent = capture.url.deletingLastPathComponent()
            if parent != pendingDirectory { _ = rmdir(parent.path) }
            pending.removeFirst()
            error = nil
            if pending.isEmpty { routerWindow?.orderOut(nil) }
        } catch { self.error = "Save failed: \(error.localizedDescription). Your screenshot is still pending; choose another folder or retry." }
    }

    func copyCapture() {
        guard let capture = pending.first else { return }
        copyToClipboard(capture.url)
    }

    func captureArea() {
        guard !isCapturingArea else { return }
        isCapturingArea = true
        hideRouter()

        let folder = pendingDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let output = folder.appendingPathComponent("Screenshot \(Int(Date().timeIntervalSince1970)).png")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-o", "-t", "png", output.path]
            process.terminationHandler = { [weak self] process in
                Task { @MainActor in
                    guard let self else { return }
                    self.isCapturingArea = false
                    guard process.terminationStatus == 0,
                          FileStamp(url: output) != nil else {
                        try? FileManager.default.removeItem(at: folder)
                        return
                    }
                    self.replacePending(with: output)
                }
            }
            try process.run()
        } catch {
            isCapturingArea = false
            try? FileManager.default.removeItem(at: folder)
            self.error = "Could not start area capture: \(error.localizedDescription)"
        }
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let additions = panel.urls
            .map(Destination.init(url:))
            .filter { candidate in !destinations.contains { $0.path == candidate.path } }
        guard !additions.isEmpty else {
            error = "Those folders are already in Destinations."
            return
        }
        destinations.append(contentsOf: additions)
        selection = additions.last?.id
        error = nil
        persist()
    }

    func requestAccessibilityPermission() {
        guard !accessibilityPermissionGranted else { return }
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        refreshPermissionStatus()
    }

    func requestScreenRecordingPermission() {
        guard !screenRecordingPermissionGranted else { return }
        _ = CGRequestScreenCaptureAccess()
        refreshPermissionStatus()
    }

    func refreshPermissionStatus() {
        accessibilityPermissionGranted = AXIsProcessTrusted()
        screenRecordingPermissionGranted = CGPreflightScreenCaptureAccess()
        startCaptureShortcutIfAllowed()
    }

    func completeSetup() {
        guard destinations.contains(where: \.writable) else { return }
        if !isolated { UserDefaults.standard.set(true, forKey: setupCompletedKey) }
        activeTab = pending.isEmpty ? .settings : .save
    }

    func remove(_ id: UUID) {
        destinations.removeAll { $0.id == id }
        if selection == id { selection = destinations.first(where: \.writable)?.id }
        persist()
    }

    func move(_ id: UUID, by offset: Int) {
        guard let index = destinations.firstIndex(where: { $0.id == id }), destinations.indices.contains(index + offset) else { return }
        destinations.swapAt(index, index + offset)
        persist()
    }

    private func persist() {
        guard !isolated else { return }
        UserDefaults.standard.set(language.rawValue, forKey: "ScreenshotRouter.language")
        do { UserDefaults.standard.set(try JSONEncoder().encode(destinations), forKey: "ScreenshotRouter.destinations") }
        catch { self.error = "Could not save destinations: \(error.localizedDescription)" }
    }

    private func copyToClipboard(_ url: URL) {
        guard let image = NSImage(contentsOf: url),
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        // Image only. A plain-text path alongside the PNG makes text-first apps
        // (Kiro chat, terminal agents, plain text fields) paste the path instead.
        let clipboard = NSPasteboard.general
        clipboard.declareTypes([.png], owner: nil)
        clipboard.setData(png, forType: .png)
    }

    private func startCaptureShortcutIfAllowed() {
        guard accessibilityPermissionGranted else { return }
        _ = captureShortcut.start { [weak self] in
            Task { @MainActor in self?.captureArea() }
        }
    }

    private func replacePending(with url: URL) {
        // A new capture starts with the name field unfocused, so ⌘C copies the image rather than the name.
        routerWindow?.makeFirstResponder(nil)
        discardPending()
        copyToClipboard(url)
        pending = [PendingCapture(url: url, discovered: Date())]
        showRouter()
    }

    private func discardPending() {
        for capture in pending {
            try? FileManager.default.removeItem(at: capture.url)
            let parent = capture.url.deletingLastPathComponent()
            if parent != pendingDirectory { _ = rmdir(parent.path) }
        }
        pending.removeAll()
    }

    func showRouter(tab: RouterTab = .save) {
        activeTab = needsInitialSetup ? .setup : tab
        if routerWindow == nil {
            let window = RouterWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 540), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.model = self
            window.title = "ScreenshotRouter"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.minSize = NSSize(width: 760, height: 540)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: RouterView(model: self))
            window.center()
            routerWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        routerWindow?.makeKeyAndOrderFront(nil)
        routerWindow?.orderFrontRegardless()
    }

    func hideRouter() { routerWindow?.orderOut(nil) }

    func showSettings() { showRouter(tab: .settings) }
}
