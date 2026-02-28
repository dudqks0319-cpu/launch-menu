import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var overlayPanelController: OverlayPanelController?
    private let store = LaunchMenuStore()
    private let hotkeyManager = GlobalHotkeyManager()
    private let hotCornerManager = HotCornerManager()
    private var settingsObserver: NSObjectProtocol?
    private var isOverlayVisible = false
    private var hasPromptedAccessibilityPermission = false

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

        hotkeyManager.start(hotkey: store.settings.toggleHotkey) { [weak self] in
            self?.toggleOverlay()
        }

        NSApp.setActivationPolicy(.accessory)
        store.start()

        applyHotkeySettings(store.settings)
        applyLaunchAtLoginSettings(store.settings)
        applyHotCornerSettings(store.settings)
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .launchMenuSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let settings = notification.object as? LaunchSettings else { return }
            Task { @MainActor in
                self?.applyHotkeySettings(settings)
                self?.applyLaunchAtLoginSettings(settings)
                self?.applyHotCornerSettings(settings)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
        hotCornerManager.stop()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
            self.settingsObserver = nil
        }
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

    private func applyHotCornerSettings(_ settings: LaunchSettings) {
        guard settings.hotCornerEnabled else {
            hotCornerManager.stop()
            return
        }

        guard hotCornerManager.hasAccessibilityPermission() else {
            if !hasPromptedAccessibilityPermission {
                hotCornerManager.requestAccessibilityPermissionPrompt()
                hasPromptedAccessibilityPermission = true
            }
            store.reportError(L10n.t("hotcorner.permission.required"))
            hotCornerManager.stop()
            return
        }
        hasPromptedAccessibilityPermission = false

        hotCornerManager.start(corner: settings.hotCornerLocation) { [weak self] in
            guard let self else { return }
            self.showOverlay()
        }
    }

    private func applyHotkeySettings(_ settings: LaunchSettings) {
        hotkeyManager.setHotkey(settings.toggleHotkey)
    }

    private func applyLaunchAtLoginSettings(_ settings: LaunchSettings) {
        guard #available(macOS 13.0, *) else {
            if settings.launchAtLoginEnabled {
                store.reportError(L10n.t("error.login.unsupported"))
            }
            return
        }

        do {
            switch SMAppService.mainApp.status {
            case .enabled where settings.launchAtLoginEnabled == false:
                try SMAppService.mainApp.unregister()
            case .notRegistered, .requiresApproval where settings.launchAtLoginEnabled:
                try SMAppService.mainApp.register()
            default:
                break
            }
        } catch {
            store.reportError(L10n.f("error.login.update.failed", error.localizedDescription))
        }
    }
}
