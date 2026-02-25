import AppKit

/// メニューバーのドロップダウンメニュー構築
enum MenuBarView {

    struct MenuItems {
        let menu: NSMenu
        let statusItem: NSMenuItem
        let modelStatusItem: NSMenuItem
        let shortcutItem: NSMenuItem
    }

    /// メニューを生成する
    /// - Parameter target: メニューアクションのターゲット（AppDelegate）
    /// - Returns: 構築済みの NSMenu と各 NSMenuItem
    static func createMenu(target: AnyObject) -> MenuItems {
        let menu = NSMenu()

        // 録音ステータス
        let statusItem = NSMenuItem(title: "録音: オフ", action: nil, keyEquivalent: "")
        menu.addItem(statusItem)

        // モデルステータス
        let modelStatusItem = NSMenuItem(title: "モデル: 未ロード", action: nil, keyEquivalent: "")
        menu.addItem(modelStatusItem)

        menu.addItem(NSMenuItem.separator())

        // ショートカット表示
        let shortcutItem = NSMenuItem(
            title: "録音開始/停止: \(AppSettings.shortcut.displayName)",
            action: nil,
            keyEquivalent: ""
        )
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)

        menu.addItem(NSMenuItem.separator())

        // 設定
        let settingsItem = NSMenuItem(
            title: "設定...",
            action: #selector(AppDelegate.openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = target
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // 終了
        let quitItem = NSMenuItem(
            title: "VoiceInput を終了",
            action: #selector(AppDelegate.quit),
            keyEquivalent: "q"
        )
        quitItem.target = target
        menu.addItem(quitItem)

        return MenuItems(
            menu: menu,
            statusItem: statusItem,
            modelStatusItem: modelStatusItem,
            shortcutItem: shortcutItem
        )
    }
}
