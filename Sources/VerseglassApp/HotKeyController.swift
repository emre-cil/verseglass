import AppKit
import Carbon.HIToolbox

/// System-wide shortcuts while Verseglass is not the active app. The status
/// menu's own key equivalents cover the moments the app is active.
@MainActor
final class HotKeyController {
    var onToggle: (() -> Void)?
    var onNudge: ((Int) -> Void)?

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    func start() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let target = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
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
            guard status == noErr else { return status }
            let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
            controller.handle(hotKeyID.id)
            return noErr
        }, 1, &spec, target, &handler)
        register(id: 1, keyCode: UInt32(kVK_ANSI_H))
        register(id: 2, keyCode: UInt32(kVK_ANSI_LeftBracket))
        register(id: 3, keyCode: UInt32(kVK_ANSI_RightBracket))
    }

    private func register(id: UInt32, keyCode: UInt32) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5647_4C53), id: id)
        let status = RegisterEventHotKey(
            keyCode,
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            refs.append(ref)
        }
    }

    private func handle(_ id: UInt32) {
        guard !NSApp.isActive else { return }
        switch id {
        case 1: onToggle?()
        case 2: onNudge?(-1)
        case 3: onNudge?(1)
        default: break
        }
    }
}
