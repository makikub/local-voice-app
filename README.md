# VoiceInput

macOS メニューバー常駐の音声入力アプリ。グローバルショートカットで録音し、WhisperKit（CoreML）でローカル音声認識、認識結果をアクティブウィンドウに自動入力する。

## 機能

- **メニューバー常駐**: Dock アイコンなし、メニューバーのマイクアイコンから操作
- **グローバルショートカット**: Cmd+Shift+V で録音開始/停止（設定で変更可）
- **ローカル音声認識**: WhisperKit + CoreML で完全オフライン動作（Apple Silicon 最適化）
- **自動テキスト入力**: 認識結果をアクティブウィンドウのカーソル位置にペースト
- **録音インジケーター**: フローティング表示で録音中の経過時間を確認
- **設定画面**: モデル選択、ショートカット変更、ログイン時起動、メモリ管理

## 必要環境

- macOS 14.0+
- Apple Silicon（CoreML バックエンド）
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## セットアップ

```bash
# XcodeGen をインストール（未導入の場合）
brew install xcodegen

# プロジェクト生成 & ビルド
cd /path/to/mac-stt-app
xcodegen generate
xcodebuild -project VoiceInput.xcodeproj -scheme VoiceInput -configuration Debug build
```

## 起動

```bash
open ~/Library/Developer/Xcode/DerivedData/VoiceInput-*/Build/Products/Debug/VoiceInput.app
```

初回起動時にオンボーディング画面が表示され、以下の権限を案内します：

1. **マイクアクセス** — 音声録音に必要
2. **アクセシビリティ** — テキスト入力（CGEvent）に必要

## 使い方

1. メニューバーにマイクアイコンが表示される
2. **Cmd+Shift+V** で録音開始（アイコンが赤に変化、フローティングインジケーター表示）
3. もう一度 **Cmd+Shift+V** で録音停止（アイコンが青に変化、認識処理中）
4. 認識完了後、アクティブウィンドウのカーソル位置にテキストが入力される

## 使用モデル

デフォルトは `openai_whisper-large-v3_turbo`（日本語高精度）。設定画面から変更可能：

| モデル | サイズ | 特徴 |
|--------|--------|------|
| Tiny | 39MB | 最速・低精度 |
| Base | 74MB | 高速・中精度 |
| Small | 244MB | バランス型 |
| Large V3 Turbo | 809MB | 推奨・高精度 |

モデルは初回使用時に自動ダウンロードされ、`~/Library/Application Support/VoiceInput/` に保存されます。

## プロジェクト構造

```
mac-stt-app/
├── project.yml                          # XcodeGen 設定
├── VoiceInput/
│   ├── App/
│   │   ├── VoiceInputApp.swift          # @main エントリポイント
│   │   └── AppDelegate.swift            # 全サービスの統合・制御
│   ├── Models/
│   │   └── AppSettings.swift            # 定数 + UserDefaults ラッパー
│   ├── Services/
│   │   ├── AudioRecorder.swift          # AVAudioRecorder WAV録音
│   │   ├── WhisperService.swift         # WhisperKit 音声認識
│   │   ├── TextInputService.swift       # ペーストボード経由テキスト入力
│   │   └── HotkeyManager.swift          # グローバルショートカット
│   ├── Views/
│   │   ├── MenuBarView.swift            # NSMenu 構築
│   │   ├── RecordingIndicator.swift     # 録音中フローティング表示
│   │   ├── SettingsView.swift           # 設定画面（SwiftUI）
│   │   └── OnboardingView.swift         # 初回起動ガイド
│   ├── Resources/
│   │   └── Assets.xcassets/
│   └── VoiceInput.entitlements
└── PLAN.md
```

## 技術スタック

- Swift 5.9 / SwiftUI + AppKit
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) 0.15.0 — CoreML 音声認識
- [HotKey](https://github.com/soffes/HotKey) 0.2.1 — グローバルショートカット
- XcodeGen — プロジェクト管理

## 注意事項

- **App Sandbox は OFF** です（グローバルショートカット・CGEvent に必要）
- 開発ビルドを繰り返すとアクセシビリティ権限が無効になることがあります。その場合は `tccutil reset Accessibility com.voiceinput.VoiceInput` で権限をリセットし、再付与してください
- Cmd+Shift+V は一部アプリの「書式なしペースト」と競合する場合があります（設定画面でショートカット変更可能）
