import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var overlayPanelController: OverlayPanelController?
    private let store = LaunchMenuStore()
    private let hotkeyManager = GlobalHotkeyManager()
    private var isOverlayVisible = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rootView = RootContentView(
            store: store,
            onCloseRequest: { [weak self] in
                self?.hideOverlay()
            }
        )

        overlayPanelController = OverlayPanelController(
            rootView: rootView,
            onEscape: { [weak self] in
                self?.hideOverlay()
            }
        )

        statusBarController = StatusBarController(onToggleRequested: { [weak self] in
            self?.toggleOverlay()
        })
        statusBarController?.setActive(false)

        hotkeyManager.start { [weak self] in
            self?.toggleOverlay()
        }

        NSApp.setActivationPolicy(.accessory)
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func toggleOverlay() {
        if isOverlayVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
        guard !isOverlayVisible else { return }
        overlayPanelController?.show()
        isOverlayVisible = true
        statusBarController?.setActive(true)
    }

    private func hideOverlay() {
        guard isOverlayVisible else { return }
        overlayPanelController?.hide()
        isOverlayVisible = false
        statusBarController?.setActive(false)
    }
}
