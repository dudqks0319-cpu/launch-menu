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
        // Option + Space
        if event.keyCode == 49 {
            let required: NSEvent.ModifierFlags = [.option]
            let ignored: NSEvent.ModifierFlags = [.command, .control, .shift]
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return flags.contains(required) && flags.intersection(ignored).isEmpty
        }

        // F4 단독 (키보드에 따라 fn 조합이 올 수 있어 function 플래그는 허용)
        if event.keyCode == 118 {
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            return flags.isEmpty
        }

        return false
    }
}
