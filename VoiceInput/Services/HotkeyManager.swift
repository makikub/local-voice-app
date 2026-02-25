import Foundation
import HotKey

/// グローバルショートカットキーの管理
/// Cmd+Shift+V で録音のトグルを行う
final class HotkeyManager {
    private let hotKey: HotKey

    /// - Parameter toggleHandler: ショートカット押下時に呼ばれるコールバック
    init(toggleHandler: @escaping () -> Void) {
        // Cmd+Shift+V をグローバルショートカットとして登録
        hotKey = HotKey(key: .v, modifiers: [.command, .shift])
        hotKey.keyDownHandler = {
            toggleHandler()
        }
    }
}
