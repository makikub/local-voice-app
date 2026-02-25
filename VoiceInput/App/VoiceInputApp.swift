import SwiftUI

/// アプリのエントリーポイント
/// メニューバー専用アプリのため、ウィンドウは持たない
@main
struct VoiceInputApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // メニューバー常駐アプリのため、メインウィンドウは持たない
        // 設定画面は AppDelegate から NSWindow で直接表示する
        Settings { EmptyView() }
    }
}
