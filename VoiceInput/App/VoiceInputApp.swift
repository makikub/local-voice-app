import SwiftUI

/// アプリのエントリーポイント
/// メニューバー専用アプリのため、ウィンドウは持たない
@main
struct VoiceInputApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // メニューバー常駐アプリのため、Windowシーンは定義しない
        Settings {
            EmptyView()
        }
    }
}
