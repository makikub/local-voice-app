# VoiceInput 開発計画

## 背景
macOS音声入力アプリ「VoiceInput」を開発中。Phase 1（録音）と Phase 2（音声認識）は完了済み。Phase 3, 4 が残っている。

## 完了済みの内容

### Phase 1: 骨格（完了）
- メニューバー常駐アプリ（NSStatusItem、LSUIElement=true でDockアイコンなし）
- Cmd+Shift+V でグローバルショートカットによる録音トグル（HotKey ライブラリ）
- AVAudioRecorder で 16kHz/Mono/16bit WAV 保存（~/Documents/VoiceInput/）
- 録音中はメニューバーアイコンが mic.fill（赤）に変化

### Phase 2: 音声認識（完了）
- WhisperKit (v0.15.0) を SPM で統合、CoreML バックエンド（Apple Silicon最適化）
- モデル: openai_whisper-large-v3_turbo（日本語精度重視）
- 初回起動時にモデル自動ダウンロード（~/Library/Application Support/VoiceInput/ 配下）
- 録音停止後に自動で音声認識実行、認識中は脳アイコン（青）表示
- メニューにモデル状態表示（ダウンロード中 XX%、ロード中、準備完了、エラー）
- os.Logger でログ出力（subsystem: com.voiceinput.VoiceInput）

## 技術スタック
- macOS 14+ / Swift 5.9 / SwiftUI + AppKit
- XcodeGen (project.yml) でプロジェクト管理
- Xcode 26.2 でビルド
- SPM依存: HotKey (0.2.1), WhisperKit (0.15.0)

## プロジェクト構造
```
mac-stt-app/
├── project.yml
├── VoiceInput/
│   ├── App/
│   │   ├── VoiceInputApp.swift          # @main エントリポイント
│   │   └── AppDelegate.swift            # メニューバー・録音・認識の統合
│   ├── Views/
│   │   └── MenuBarView.swift            # NSMenu 構築
│   ├── Services/
│   │   ├── AudioRecorder.swift          # AVAudioRecorder WAV録音
│   │   ├── WhisperService.swift         # WhisperKit 音声認識
│   │   ├── TextInputService.swift       # ペーストボード経由テキスト入力
│   │   └── HotkeyManager.swift          # グローバルショートカット
│   ├── Models/
│   │   └── AppSettings.swift            # 定数・設定
│   ├── Resources/
│   │   └── Assets.xcassets/
│   └── VoiceInput.entitlements
```

## Phase 3: テキスト入力（完了）

- [x] TextInputService.swift 新規作成
  - ペーストボード経由のテキスト入力（NSPasteboard にテキストをコピー → Cmd+V をCGEventでシミュレート）
  - 日本語の直接キーストローク入力は複雑なため、ペーストボード方式を採用
  - 元のクリップボード内容を退避・復元する処理（200ms 遅延で復元）
- [x] アクセシビリティ権限の確認・案内
  - CGEvent の使用にアクセシビリティ権限が必要
  - AXIsProcessTrusted() で権限チェック
  - 未許可時に AXIsProcessTrustedWithOptions で自動的にシステム設定へ誘導
- [x] AppDelegate 改修
  - setupTextInputService() 追加、起動時にアクセシビリティ権限チェック
  - 認識完了後に textInputService.insertText() でアクティブウィンドウにペースト
- [x] ビルド確認

## 残りの Phase

### Phase 4: UI/UX
- [ ] RecordingIndicator.swift 新規作成
  - 録音中の小さなフローティングインジケーター（録音時間表示）
  - NSPanel を使ったフローティングウィンドウ
  - 常に最前面、クリックスルー可能
- [ ] SettingsView.swift 新規作成（SwiftUI）
  - ショートカットキーの変更
  - Whisperモデルの選択（tiny / base / small / medium / large-v3-turbo）
  - マイクデバイスの選択
  - 「ログイン時に起動」オプション
- [ ] OnboardingView.swift 新規作成
  - 初回起動時の権限案内（マイク、アクセシビリティ）
  - ステップバイステップのガイド
- [ ] エラーハンドリング強化
  - エラー時に通知センターでユーザーに通知（UNUserNotificationCenter）
  - モデルDL失敗時のリトライ機能
- [ ] AppSettings を UserDefaults ラッパーに拡張
- [ ] メモリ管理オプション（認識完了後にモデルをアンロードするオプション）
- [ ] ビルド確認・動作テスト

## 既知の注意点
- App Sandbox: OFF（グローバルショートカット・CGEvent に必要）
- SWIFT_STRICT_CONCURRENCY: minimal（WhisperKit の Swift 6 対応が途中のため）
- AppDelegate は @MainActor（WhisperService の @MainActor との整合性のため）
- os.Logger の文字列補間はプライバシー保護で <private> にマスクされる（log show 時）
- Cmd+Shift+V は一部アプリの「書式なしペースト」と競合する可能性あり（Phase 4 でカスタマイズ可能に）

## ビルド手順
```bash
cd /Users/m.kubota/src/mac-stt-app
xcodegen generate
xcodebuild -project VoiceInput.xcodeproj -scheme VoiceInput -configuration Debug build
# アプリ起動
open ~/Library/Developer/Xcode/DerivedData/VoiceInput-eqcziekyotbestblyaszsantgqlz/Build/Products/Debug/VoiceInput.app
```
