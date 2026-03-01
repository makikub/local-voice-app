# CLAUDE.md - VoiceInput

## プロジェクト概要

macOS メニューバー常駐の音声入力アプリ。ショートカットキーで録音 → WhisperKit でローカル音声認識 → アクティブウィンドウにテキスト入力。

## ビルド

```bash
xcodegen generate
xcodebuild -project VoiceInput.xcodeproj -scheme VoiceInput -configuration Debug build
```

アプリ実行:
```bash
open ~/Library/Developer/Xcode/DerivedData/VoiceInput-*/Build/Products/Debug/VoiceInput.app
```

実装完了後の確認（ビルド後に必ず実行すること）:
```bash
tccutil reset Accessibility com.voiceinput.VoiceInput
pkill -x VoiceInput
open ~/Library/Developer/Xcode/DerivedData/VoiceInput-*/Build/Products/Debug/VoiceInput.app
```

## アーキテクチャ

AppDelegate がハブとして全サービスを統合する構成。

```
HotkeyManager → AppDelegate → AudioRecorder (WAV録音)
                            → WhisperService (音声認識)
                            → TextInputService (テキスト入力)
                            → RecordingIndicator (UI)
```

### レイヤー

- **App/**: エントリポイント (VoiceInputApp) と統合制御 (AppDelegate)
- **Services/**: 独立した機能モジュール。各 Service は AppDelegate からのみ呼ばれる
- **Views/**: UI コンポーネント。MenuBarView は AppKit、他は SwiftUI
- **Models/**: AppSettings（定数 + UserDefaults ラッパー）

### 主要な型

| 型 | Actor | 役割 |
|----|-------|------|
| AppDelegate | @MainActor | 全サービスのライフサイクル管理 |
| WhisperService | @MainActor | モデル DL/ロード/認識。state プロパティで状態管理 |
| TextInputService | @MainActor | NSPasteboard + CGEvent Cmd+V でテキスト入力 |
| AudioRecorder | nonisolated | AVAudioRecorder で 16kHz/Mono WAV 録音 |
| HotkeyManager | nonisolated | HotKey ライブラリのラッパー |
| AppSettings | enum (static) | UserDefaults の get/set を static var で提供 |

## 技術的制約

- **App Sandbox: OFF** — グローバルショートカット (HotKey) と CGEvent (TextInputService) に必要
- **SWIFT_STRICT_CONCURRENCY: minimal** — WhisperKit の Swift 6 対応が途上のため
- **LSUIElement: true** — Dock アイコンなし。Settings シーンが開きにくいため、設定は NSWindow で直接表示
- **アクセシビリティ権限** — CGEvent の使用に必須。開発ビルドでは再ビルド後にリセットが必要になることがある
- **os.Logger のプライバシー** — 文字列補間は log show で `<private>` にマスクされる。重要なログは `.notice` レベルを使用

## 依存関係

- **HotKey** (0.2.1) — グローバルショートカット。`Key` enum と `NSEvent.ModifierFlags` で定義
- **WhisperKit** (0.15.0) — CoreML ベースの音声認識。モデルは `~/Library/Application Support/VoiceInput/` に保存

## コーディング規約

- サービスクラスは `final class` で定義
- UI スレッドで動作する型には `@MainActor` を付与
- ログは `os.Logger` を使用（subsystem: `com.voiceinput.VoiceInput`）
- 設定の追加は AppSettings に UserDefaults キーとプロパティを追加する形式
