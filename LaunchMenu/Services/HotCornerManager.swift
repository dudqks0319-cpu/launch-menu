import ApplicationServices
import AppKit
import Foundation

final class HotCornerManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onTrigger: (() -> Void)?
    private var targetCorner: HotCornerLocation = .topLeft
    private var enteredAt: Date?
    private var hasTriggered = false

    private let dwellTime: TimeInterval = 0.3
    private let cornerTolerance: CGFloat = 3.0

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermissionPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func start(corner: HotCornerLocation, onTrigger: @escaping () -> Void) {
        stop()

        self.targetCorner = corner
        self.onTrigger = onTrigger
        self.enteredAt = nil
        self.hasTriggered = false

        let mask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)
            | (1 << CGEventType.otherMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotCornerManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleEvent(type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return
        }

        eventTap = tap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            stop()
            return
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        onTrigger = nil
        enteredAt = nil
        hasTriggered = false
    }

    deinit {
        stop()
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged else {
            return Unmanaged.passUnretained(event)
        }

        let location = event.location
        updateCornerState(for: location)

        return Unmanaged.passUnretained(event)
    }

    private func updateCornerState(for point: CGPoint) {
        guard isPointInTargetCorner(point) else {
            enteredAt = nil
            hasTriggered = false
            return
        }

        if enteredAt == nil {
            enteredAt = Date()
            hasTriggered = false
            return
        }

        guard hasTriggered == false, let enteredAt else {
            return
        }

        if Date().timeIntervalSince(enteredAt) >= dwellTime {
            hasTriggered = true
            DispatchQueue.main.async { [weak self] in
                self?.onTrigger?()
            }
        }
    }

    private func isPointInTargetCorner(_ point: CGPoint) -> Bool {
        let screenFrames = NSScreen.screens.map(\.frame)
        guard screenFrames.isEmpty == false else { return false }

        let minX = screenFrames.map(\.minX).min() ?? 0
        let maxX = screenFrames.map(\.maxX).max() ?? 0
        let minY = screenFrames.map(\.minY).min() ?? 0
        let maxY = screenFrames.map(\.maxY).max() ?? 0

        switch targetCorner {
        case .topLeft:
            return point.x <= minX + cornerTolerance && point.y >= maxY - cornerTolerance
        case .topRight:
            return point.x >= maxX - cornerTolerance && point.y >= maxY - cornerTolerance
        case .bottomLeft:
            return point.x <= minX + cornerTolerance && point.y <= minY + cornerTolerance
        case .bottomRight:
            return point.x >= maxX - cornerTolerance && point.y <= minY + cornerTolerance
        }
    }
}
