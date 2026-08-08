import Carbon
import Foundation

struct HotkeyCombo: Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    static let `default` = HotkeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(cmdKey))
}

@MainActor
final class HotkeyTrigger: ActivationTrigger {
    let id = TriggerKind.hotkey.rawValue

    private let combo: HotkeyCombo
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var onActivate: (() -> Void)?
    private let signature = OSType(0x414D4E49) // AMNI

    init(combo: HotkeyCombo = .default) {
        self.combo = combo
    }

    func start(onActivate: @escaping () -> Void) {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                let trigger = Unmanaged<HotkeyTrigger>.fromOpaque(context).takeUnretainedValue()
                return trigger.handleCarbonEvent(event)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            eventHandler = nil
            return
        }

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let registerStatus = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            hotKeyRef = nil
            if let eventHandler { RemoveEventHandler(eventHandler) }
            eventHandler = nil
            return
        }

        self.onActivate = onActivate
    }

    func stop() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
        onActivate = nil
    }

    // `handleCarbonEvent` is reached via `Unmanaged.passUnretained(self)` from the Carbon event
    // handler, so nothing keeps this object alive on its behalf — if a future refactor ever
    // deallocates a trigger without calling `stop()` first (today `AppModel` holds it for the
    // process lifetime, so this doesn't fire in practice), the next system callback would
    // dereference a dangling pointer. Belt-and-suspenders cleanup.
    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    private func handleCarbonEvent(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, hotKeyID.signature == signature else {
            return OSStatus(eventNotHandledErr)
        }
        DispatchQueue.main.async { [weak self] in
            self?.onActivate?()
        }
        return noErr
    }
}
