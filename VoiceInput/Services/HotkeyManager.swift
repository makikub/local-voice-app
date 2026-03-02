import AppKit
import HotKey

/// グローバルショートカットキーの管理
/// AppSettings のショートカット設定に基づいてホットキーを登録する
final class HotkeyManager {
    private var hotKey: HotKey?
    private var escapeHotKey: HotKey?
    private let keyDownHandler: () -> Void
    private let keyUpHandler: (() -> Void)?

    /// keyUp 検知用のグローバルイベントモニター
    /// Carbon API の kEventHotKeyReleased は修飾キー付きホットキーで信頼性が低いため、
    /// PTT モードでは NSEvent のグローバルモニターで keyUp を検知する
    private var keyUpMonitor: Any?
    private var currentModifiers: NSEvent.ModifierFlags = []
    private var currentKeyCode: UInt32 = 0

    /// - Parameters:
    ///   - keyDownHandler: ホットキー押下時に呼ばれるコールバック
    ///   - keyUpHandler: ホットキー離上時に呼ばれるコールバック（Push-to-Talk モード用）
    init(keyDownHandler: @escaping () -> Void, keyUpHandler: (() -> Void)? = nil) {
        self.keyDownHandler = keyDownHandler
        self.keyUpHandler = keyUpHandler
        applyShortcut(AppSettings.shortcut)
    }

    /// ショートカットを変更する
    func applyShortcut(_ option: ShortcutOption) {
        hotKey = nil
        removeKeyUpMonitor()

        let (key, modifiers) = keyAndModifiers(for: option)
        currentKeyCode = key.carbonKeyCode
        currentModifiers = modifiers
        hotKey = HotKey(key: key, modifiers: modifiers)

        if keyUpHandler != nil {
            // PTT モード: keyDown でモニター設置、モニター側で keyUp を検知
            hotKey?.keyDownHandler = { [weak self] in
                self?.keyDownHandler()
                self?.installKeyUpMonitor()
            }
            // Carbon の keyUpHandler は使わない（修飾キー付きホットキーで信頼性が低い）
        } else {
            // トグルモード: keyDown のみ
            hotKey?.keyDownHandler = { [weak self] in
                self?.keyDownHandler()
            }
        }
    }

    /// 録音中のみ Esc キーを登録する
    func registerEscape(handler: @escaping () -> Void) {
        escapeHotKey = HotKey(key: .escape, modifiers: [])
        escapeHotKey?.keyDownHandler = handler
    }

    /// Esc キーの登録を解除する
    func unregisterEscape() {
        escapeHotKey = nil
    }

    // MARK: - PTT keyUp 検知

    /// グローバルイベントモニターを設置して keyUp を検知する
    private func installKeyUpMonitor() {
        removeKeyUpMonitor()

        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp, .flagsChanged]) { [weak self] event in
            self?.handleKeyUpEvent(event)
        }
    }

    /// キーリリースイベントを処理する
    private func handleKeyUpEvent(_ event: NSEvent) {
        switch event.type {
        case .keyUp:
            // メインキー（V, Space 等）が離された
            if UInt32(event.keyCode) == currentKeyCode {
                fireKeyUp()
            }
        case .flagsChanged:
            // 修飾キーが離された（現在の修飾キーが必要な修飾キーを満たさなくなった）
            let required = currentModifiers.intersection([.command, .shift, .control, .option])
            let current = event.modifierFlags.intersection([.command, .shift, .control, .option])
            if !current.contains(required) {
                fireKeyUp()
            }
        default:
            break
        }
    }

    /// keyUpHandler を呼んでモニターを解除する
    private func fireKeyUp() {
        removeKeyUpMonitor()
        keyUpHandler?()
    }

    /// グローバルイベントモニターを解除する
    private func removeKeyUpMonitor() {
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }
    }

    private func keyAndModifiers(for option: ShortcutOption) -> (Key, NSEvent.ModifierFlags) {
        switch option {
        case .cmdShiftV:
            return (.v, [.command, .shift])
        case .cmdShiftSpace:
            return (.space, [.command, .shift])
        case .ctrlOptionV:
            return (.v, [.control, .option])
        }
    }
}
