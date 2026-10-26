import AppKit

@MainActor
final class RouterWindow: NSWindow {
    weak var model: RouterModel?

    override func sendEvent(_ event: NSEvent) {
        guard isKeyWindow, event.type == .keyDown, let model else {
            super.sendEvent(event)
            return
        }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if modifiers.isEmpty && event.keyCode == 53 {
            model.hideRouter()
            return
        }
        // Return saves here rather than through the text field's submit action, which also fires when the field loses focus.
        if modifiers.isEmpty && model.activeTab == .save && (event.keyCode == 36 || event.keyCode == 76) {
            // Let the input method finish a word still being composed (such as a Hangul syllable) first.
            if (firstResponder as? NSTextView)?.hasMarkedText() == true { super.sendEvent(event) }
            if !event.isARepeat && model.canSave && (firstResponder as? NSTextView)?.hasMarkedText() != true { model.save() }
            return
        }
        if modifiers == .command && event.keyCode == 1 {
            if !event.isARepeat && model.canSave { model.save() }
            return
        }
        if modifiers == .command,
           let key = event.charactersIgnoringModifiers?.lowercased(),
           let number = Int(key), (1...9).contains(number) {
            let index = number - 1
            if !event.isARepeat, model.destinations.indices.contains(index),
               model.destinations[index].writable, !model.pending.isEmpty {
                model.save(to: model.destinations[index])
            }
            return
        }
        super.sendEvent(event)
    }

    // ⌘C is an Edit menu key equivalent, which runs before sendEvent; the key window gets it first here.
    // Outside the name field it copies the capture image again instead of doing nothing.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if modifiers == .command, event.keyCode == 8, !(firstResponder is NSText), let model, !model.pending.isEmpty {
            model.copyCapture()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
