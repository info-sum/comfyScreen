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
}
