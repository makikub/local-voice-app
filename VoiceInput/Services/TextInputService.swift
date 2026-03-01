import AppKit
import os

/// 認識結果テキストをアクティブウィンドウに入力するサービス
/// ペーストボード経由（NSPasteboard → Cmd+V シミュレート）で入力する
@MainActor
final class TextInputService {

    private let logger = Logger(subsystem: "com.voiceinput.VoiceInput", category: "TextInputService")

    // MARK: - アクセシビリティ権限

    /// アクセシビリティ権限が付与されているか確認
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// アクセシビリティ権限を要求（システム設定ダイアログを表示）
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - テキスト入力

    /// テキストをアクティブウィンドウのカーソル位置にペーストする
    /// - Parameter text: 入力するテキスト
    /// - Returns: 成功したかどうか
    @discardableResult
    func insertText(_ text: String) -> Bool {
        guard Self.isAccessibilityGranted else {
            logger.warning("アクセシビリティ権限がありません")
            Self.requestAccessibility()
            return false
        }

        // 1. 現在のクリップボード内容を退避
        let pasteboard = NSPasteboard.general
        let previousContents = backupPasteboard(pasteboard)

        // 2. 認識テキストをクリップボードにセット
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Cmd+V をシミュレートしてペースト
        let pasted = simulatePaste()

        // 4. ペースト先アプリがクリップボードを読み取る時間を確保してから復元
        // 200ms ではElectron系アプリやIDEで不足するケースがあるため、
        // changeCount を監視して読み取り完了を待つ（最大1秒）
        let changeCountAfterSet = pasteboard.changeCount
        DispatchQueue.global(qos: .userInitiated).async {
            let maxWait = 1.0
            let interval = 0.05
            var elapsed = 0.0

            // ペースト先がクリップボードを読むと changeCount が変わる場合がある
            // 変わらなくても最低 500ms は待つ（安全マージン）
            while elapsed < maxWait {
                Thread.sleep(forTimeInterval: interval)
                elapsed += interval
                if elapsed >= 0.5 && pasteboard.changeCount != changeCountAfterSet {
                    break
                }
            }

            DispatchQueue.main.async {
                self.restorePasteboard(pasteboard, contents: previousContents)
            }
        }

        if pasted {
            logger.notice("テキスト入力完了（\(text.count)文字）")
        } else {
            logger.error("テキスト入力失敗: CGEvent 作成エラー")
        }

        return pasted
    }

    // MARK: - プライベート

    /// ペーストボードの内容を退避
    private func backupPasteboard(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        var backup: [NSPasteboardItem] = []
        guard let items = pasteboard.pasteboardItems else { return backup }

        for item in items {
            let backupItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    backupItem.setData(data, forType: type)
                }
            }
            backup.append(backupItem)
        }
        return backup
    }

    /// ペーストボードの内容を復元
    private func restorePasteboard(_ pasteboard: NSPasteboard, contents: [NSPasteboardItem]) {
        guard !contents.isEmpty else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects(contents)
    }

    /// CGEvent で Cmd+V キーストロークをシミュレート
    private func simulatePaste() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)

        // 'v' キーの仮想キーコード = 9
        let keyCodeV: CGKeyCode = 9

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false) else {
            return false
        }

        // Command フラグを付与
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // イベントを送信
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}
