import AppKit

final class GlobalHotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var onToggle: (() -> Void)?

    func start(onToggle: @escaping () -> Void) {
        stop()
        self.onToggle = onToggle

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        onToggle = nil
    }

    deinit {
        stop()
    }

    private func handle(_ event: NSEvent) {
        guard isToggleHotkey(event) else { return }
        onToggle?()
    }

    private func isToggleHotkey(_ event: NSEvent) -> Bool {
        // Command + L
        guard event.keyCode == 37 else { return false }
        let required: NSEvent.ModifierFlags = [.command]
        let ignored: NSEvent.ModifierFlags = [.option, .control, .shift]
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(required) && flags.intersection(ignored).isEmpty
    }
}
