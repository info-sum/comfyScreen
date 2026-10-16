import ApplicationServices
import Foundation

final class CaptureShortcutMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var action: (() -> Void)?

    @discardableResult
    func start(action: @escaping () -> Void) -> Bool {
        self.action = action
        guard eventTap == nil else { return true }
        guard AXIsProcessTrusted() else { return false }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<CaptureShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let eventTap = monitor.eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                let modifiers = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
                guard type == .keyDown,
                      event.getIntegerValueField(.keyboardEventKeycode) == 21,
                      event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
                      modifiers == [.maskCommand, .maskShift] else {
                    return Unmanaged.passUnretained(event)
                }
                monitor.action?()
                return nil
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let eventTap else { return false }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        return true
    }
}
