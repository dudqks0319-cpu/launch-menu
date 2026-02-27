import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onToggleRequested: () -> Void

    init(onToggleRequested: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onToggleRequested = onToggleRequested
        super.init()
        configureButton()
    }

    func setActive(_ isActive: Bool) {
        statusItem.button?.contentTintColor = isActive ? .controlAccentColor : nil
    }

    @objc private func didTapStatusItem(_ sender: Any?) {
        onToggleRequested()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "LaunchMenu")
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(didTapStatusItem(_:))
    }
}
