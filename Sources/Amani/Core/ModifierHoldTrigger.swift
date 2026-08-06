import Carbon
import CoreGraphics
import Foundation
import QuartzCore

enum ModifierHoldEvent: Equatable {
    case none
    case fire
    case cancelled
}

/// Pure state machine: idle -> holding -> fired/cancelled. Driven by timestamps, not real time,
/// so it's fully deterministic and fast to test. `ModifierHoldTrigger` below feeds it real
/// CGEventTap timestamps.
struct ModifierHoldStateMachine {
    private enum State {
        case idle
        case holding(since: TimeInterval)
        case fired
    }

    let thresholdSeconds: TimeInterval
    private var state: State = .idle

    init(thresholdSeconds: TimeInterval) {
        self.thresholdSeconds = thresholdSeconds
    }

    mutating func modifierDown(at timestamp: TimeInterval) -> ModifierHoldEvent {
        state = .holding(since: timestamp)
        return .none
    }

    mutating func modifierUp(at timestamp: TimeInterval) -> ModifierHoldEvent {
        switch state {
        case .holding:
            state = .idle
            return .cancelled
        case .fired:
            state = .idle
            return .none
        case .idle:
            return .none
        }
    }

    mutating func otherKeyOrModifierEvent(at timestamp: TimeInterval) -> ModifierHoldEvent {
        switch state {
        case .holding:
            state = .idle
            return .cancelled
        case .fired, .idle:
            return .none
        }
    }

    mutating func tick(at timestamp: TimeInterval) -> ModifierHoldEvent {
        guard case .holding(let since) = state else { return .none }
        guard timestamp - since >= thresholdSeconds else { return .none }
        state = .fired
        return .fire
    }
}

@MainActor
final class ModifierHoldTrigger: ActivationTrigger {
    let id = TriggerKind.modifierHold.rawValue

    private let thresholdSeconds: TimeInterval
    private var machine: ModifierHoldStateMachine
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?
    private var onActivate: (() -> Void)?

    init(thresholdSeconds: TimeInterval = 5.0) {
        self.thresholdSeconds = thresholdSeconds
        self.machine = ModifierHoldStateMachine(thresholdSeconds: thresholdSeconds)
    }

    func start(onActivate: @escaping () -> Void) {
        guard CGPreflightListenEventAccess() else { return } // Input Monitoring not granted yet
        guard eventTap == nil else {
            self.onActivate = onActivate
            return
        }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue) | CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let trigger = Unmanaged<ModifierHoldTrigger>.fromOpaque(context).takeUnretainedValue()
                trigger.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }

        self.onActivate = onActivate
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollHoldThreshold() }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        runLoopSource = nil
        eventTap = nil
        onActivate = nil
        machine = ModifierHoldStateMachine(thresholdSeconds: thresholdSeconds)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // Fail safe: never arm while a secure-input field (e.g. a password field) is focused.
        guard !IsSecureEventInputEnabled() else { return }

        let timestamp = TimeInterval(event.timestamp) / 1_000_000_000
        var outcome: ModifierHoldEvent = .none

        if type == .keyDown {
            outcome = machine.otherKeyOrModifierEvent(at: timestamp)
        } else if type == .flagsChanged {
            let flags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
            if flags == .maskCommand {
                outcome = machine.modifierDown(at: timestamp)
            } else if flags.isEmpty {
                outcome = machine.modifierUp(at: timestamp)
            } else {
                outcome = machine.otherKeyOrModifierEvent(at: timestamp)
            }
        }

        if outcome == .fire {
            DispatchQueue.main.async { [weak self] in self?.onActivate?() }
        }
    }

    private func pollHoldThreshold() {
        guard !IsSecureEventInputEnabled() else { return }
        let now = TimeInterval(CACurrentMediaTime())
        if machine.tick(at: now) == .fire {
            DispatchQueue.main.async { [weak self] in self?.onActivate?() }
        }
    }
}
