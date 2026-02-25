import AVFoundation
import SwiftUI

/// 初回起動時のオンボーディング画面
/// マイクとアクセシビリティの権限取得をステップバイステップで案内する
struct OnboardingView: View {

    @State private var micGranted = false
    @State private var accessibilityGranted = false
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            VStack(spacing: 8) {
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                Text("VoiceInput へようこそ")
                    .font(.title2.bold())
                Text("音声入力を使うために、2つの権限が必要です。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            // ステップ一覧
            VStack(alignment: .leading, spacing: 16) {
                // Step 1: マイク
                PermissionRow(
                    step: 1,
                    title: "マイクへのアクセス",
                    description: "音声を録音するために必要です。",
                    iconName: "mic.fill",
                    isGranted: micGranted,
                    action: requestMicPermission
                )

                // Step 2: アクセシビリティ
                PermissionRow(
                    step: 2,
                    title: "アクセシビリティ",
                    description: "認識したテキストを入力するために必要です。\nシステム設定で VoiceInput を許可してください。",
                    iconName: "hand.raised.fill",
                    isGranted: accessibilityGranted,
                    action: requestAccessibilityPermission
                )
            }
            .padding(20)

            Spacer()

            // 完了ボタン
            Button(action: {
                AppSettings.hasCompletedOnboarding = true
                onComplete()
            }) {
                Text(allGranted ? "始める" : "スキップして始める")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 400, height: 420)
        .onAppear {
            checkPermissions()
        }
    }

    private var allGranted: Bool {
        micGranted && accessibilityGranted
    }

    private func checkPermissions() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
    }

    private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in
                micGranted = granted
            }
        }
    }

    private func requestAccessibilityPermission() {
        TextInputService.requestAccessibility()
        // ポーリングで権限付与を検知
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                if AXIsProcessTrusted() {
                    accessibilityGranted = true
                    timer.invalidate()
                }
            }
        }
    }
}

// MARK: - 権限行

private struct PermissionRow: View {
    let step: Int
    let title: String
    let description: String
    let iconName: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // ステップ番号 / チェックマーク
            ZStack {
                Circle()
                    .fill(isGranted ? .green : .secondary.opacity(0.2))
                    .frame(width: 28, height: 28)
                if isGranted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(step)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: iconName)
                        .foregroundStyle(isGranted ? .green : .blue)
                    Text(title)
                        .font(.headline)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !isGranted {
                    Button("許可する") {
                        action()
                    }
                    .controlSize(.small)
                    .padding(.top, 2)
                }
            }
        }
    }
}
