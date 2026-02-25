import AppKit
import SwiftUI

/// 録音中に画面上部に表示するフローティングインジケーター
/// NSPanel を使い、常に最前面で表示する
@MainActor
final class RecordingIndicator {

    private var panel: NSPanel?
    private var startTime: Date?
    private var timer: Timer?
    private let timerModel = RecordingTimerModel()

    /// インジケーターを表示して計時を開始
    func show() {
        guard panel == nil else { return }

        startTime = Date()
        timerModel.elapsed = 0

        let hostingView = NSHostingView(rootView: RecordingIndicatorView(timerModel: timerModel))
        hostingView.setFrameSize(NSSize(width: 160, height: 36))

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 36),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 画面上部中央に配置
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.midX - 80
            let y = frame.maxY - 50
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        self.panel = panel

        // 0.1秒ごとに経過時間を更新
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.startTime else { return }
                self.timerModel.elapsed = Date().timeIntervalSince(startTime)
            }
        }
    }

    /// インジケーターを非表示にして計時を停止
    func hide() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        panel?.close()
        panel = nil
    }
}

// MARK: - タイマーモデル

@MainActor
final class RecordingTimerModel: ObservableObject {
    @Published var elapsed: TimeInterval = 0

    var formattedTime: String {
        let total = Int(elapsed)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - SwiftUI ビュー

struct RecordingIndicatorView: View {
    @ObservedObject var timerModel: RecordingTimerModel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
            Text("録音中")
                .font(.system(size: 12, weight: .medium))
            Text(timerModel.formattedTime)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
