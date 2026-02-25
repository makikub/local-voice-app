import AppKit

/// メニューバーのドロップダウンメニュー構築
enum MenuBarView {
    /// メニューを生成する
    /// - Parameter target: メニューアクションのターゲット（AppDelegate）
    /// - Returns: 構築済みの NSMenu、録音ステータス、モデルステータスの各 NSMenuItem
    static func createMenu(target: AnyObject) -> (menu: NSMenu, statusItem: NSMenuItem, modelStatusItem: NSMenuItem) {
        let menu = NSMenu()

        // 録音ステータス
        let statusItem = NSMenuItem(title: "録音: オフ", action: nil, keyEquivalent: "")
        menu.addItem(statusItem)

        // モデルステータス（Phase 2 追加）
        let modelStatusItem = NSMenuItem(title: "モデル: 未ロード", action: nil, keyEquivalent: "")
        menu.addItem(modelStatusItem)

        menu.addItem(NSMenuItem.separator())

        let shortcutItem = NSMenuItem(title: "録音開始/停止: ⌘⇧V", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "VoiceInput を終了", action: #selector(AppDelegate.quit), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return (menu, statusItem, modelStatusItem)
    }
}
