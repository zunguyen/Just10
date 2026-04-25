import AppKit
import Carbon.HIToolbox

/// Plain struct used both for storage and recorder UI.
struct HotkeyCombo: Equatable, Codable {
    var keyCode: UInt32
    /// Carbon modifier flags (cmdKey | optionKey | controlKey | shiftKey).
    var carbonModifiers: UInt32

    /// Default: ⌃⌥Space
    static let defaultCombo = HotkeyCombo(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(controlKey | optionKey)
    )

    var displayString: String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            // Best-effort character lookup for letter/digit keys.
            if let char = characterForKeyCode(keyCode) {
                return String(char).uppercased()
            }
            return "Key \(keyCode)"
        }
    }

    private static func characterForKeyCode(_ keyCode: UInt32) -> Character? {
        guard let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let dataPtr = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { raw -> Character? in
            guard let base = raw.baseAddress else { return nil }
            let keyLayout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(
                keyLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
            guard status == noErr, length > 0,
                  let scalar = Unicode.Scalar(chars[0]) else { return nil }
            return Character(scalar)
        }
    }
}

/// Registers a single Carbon hot key globally and invokes `onTrigger` when pressed.
final class GlobalHotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onTrigger: (() -> Void)?

    deinit { unregister() }

    func register(_ combo: HotkeyCombo) {
        unregister()

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D425444 /* "MBTD" */), id: 1)
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                hotkey.onTrigger?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handler { RemoveEventHandler(handler) }
        hotKeyRef = nil
        handler = nil
    }
}
