import AppKit

final class GlobalHotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var onToggle: (() -> Void)?
    private var toggleHotkey: LaunchToggleHotkey = .commandL

    func start(hotkey: LaunchToggleHotkey, onToggle: @escaping () -> Void) {
        stop()
        self.toggleHotkey = hotkey
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

    func setHotkey(_ hotkey: LaunchToggleHotkey) {
        toggleHotkey = hotkey
    }

    private func handle(_ event: NSEvent) {
        guard isToggleHotkey(event) else { return }
        onToggle?()
    }

    private func isToggleHotkey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowed: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

        switch toggleHotkey {
        case .commandL:
            return event.keyCode == 37 && flags == [.command]
        case .optionSpace:
            return event.keyCode == 49 && flags == [.option]
        case .f4:
            return event.keyCode == 118 && flags.intersection(disallowed).isEmpty
        }
    }
}
