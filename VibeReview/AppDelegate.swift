import AppKit
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let captureMoment = Self("captureMoment", default: .init(.r, modifiers: [.command, .shift]))
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sessionStore = SessionStore()
    private let browserServer = BrowserSnapshotServer()
    private var mainWindow: NSWindow?
    private var overlayPanel: FloatingPanel?
    private var promptPanel: FloatingPanel?
    private var overlayHUDVisible = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureApplicationIcon()
        browserServer.start()
        showMainWindow()
        showOverlay()
        setupShortcut()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func setupShortcut() {
        KeyboardShortcuts.onKeyUp(for: .captureMoment) { [weak self] in
            Task { @MainActor in
                await self?.beginCapture()
            }
        }
    }

    private func configureApplicationIcon() {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
    }

    private func showMainWindow() {
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ContentView(
            sessionStore: sessionStore,
            browserServer: browserServer,
            overlayHUDVisible: overlayHUDVisible,
            onOverlayHUDVisibilityChanged: { [weak self] isVisible in
                self?.setOverlayHUDVisible(isVisible)
            }
        )
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "VibeReview"
        window.contentView = hosting
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = window
    }

    private func showOverlay() {
        guard overlayHUDVisible else {
            overlayPanel?.orderOut(nil)
            return
        }

        if let overlayPanel {
            overlayPanel.orderFront(nil)
            return
        }

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1200, height: 800)
        let frame = NSRect(x: visibleFrame.maxX - 300, y: visibleFrame.maxY - 84, width: 280, height: 64)
        let panel = FloatingPanel(contentRect: frame, styleMask: [], backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: OverlayView(sessionStore: sessionStore, browserServer: browserServer))
        panel.orderFront(nil)
        overlayPanel = panel
    }

    private func setOverlayHUDVisible(_ isVisible: Bool) {
        overlayHUDVisible = isVisible
        if isVisible {
            showOverlay()
        } else {
            overlayPanel?.orderOut(nil)
        }
    }

    private func beginCapture() async {
        guard sessionStore.activeSession != nil else {
            NSSound.beep()
            showMainWindow()
            return
        }

        let shouldRestoreOverlay = overlayHUDVisible && overlayPanel?.isVisible == true
        overlayPanel?.orderOut(nil)
        if shouldRestoreOverlay {
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        defer {
            if shouldRestoreOverlay {
                overlayPanel?.orderFront(nil)
            }
        }

        do {
            let pending = try sessionStore.createPendingCapture(browserSnapshot: browserServer.lastSnapshot)
            showPrompt(for: pending)
        } catch {
            sessionStore.lastError = error.localizedDescription
            NSSound.beep()
            showMainWindow()
        }
    }

    private func showPrompt(for pending: PendingCapture) {
        promptPanel?.orderOut(nil)

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1200, height: 800)
        let frame = NSRect(
            x: visibleFrame.midX - 260,
            y: visibleFrame.midY - 228,
            width: 520,
            height: 456
        )
        let panel = FloatingPanel(contentRect: frame, styleMask: [], backing: .buffered, defer: false)
        panel.level = .modalPanel
        panel.contentView = NSHostingView(rootView: CapturePromptView(
            pending: pending,
            sessionStore: sessionStore,
            onDone: { [weak self] in
                self?.promptPanel?.orderOut(nil)
                self?.promptPanel = nil
            }
        ))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        promptPanel = panel
    }
}
