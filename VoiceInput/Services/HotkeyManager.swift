import AppKit
import HotKey

/// グローバルショートカットキーの管理
/// AppSettings のショートカット設定に基づいてホットキーを登録する
final class HotkeyManager {
    private var hotKey: HotKey?
    private var escapeHotKey: HotKey?
    private let toggleHandler: () -> Void

    /// - Parameter toggleHandler: ショートカット押下時に呼ばれるコールバック
    init(toggleHandler: @escaping () -> Void) {
        self.toggleHandler = toggleHandler
        applyShortcut(AppSettings.shortcut)
    }

    /// ショートカットを変更する
    func applyShortcut(_ option: ShortcutOption) {
        hotKey = nil

        let (key, modifiers) = keyAndModifiers(for: option)
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleHandler()
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
