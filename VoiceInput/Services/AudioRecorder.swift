import Foundation
import AVFoundation

/// マイク録音の管理
/// AVAudioRecorder を使用して WAV (Linear PCM) 形式で保存する
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private(set) var isRecording = false

    /// Whisper 向けに最適化された録音設定
    /// 16kHz / モノラル / 16bit Linear PCM
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: AppSettings.sampleRate,
        AVNumberOfChannelsKey: AppSettings.channels,
        AVLinearPCMBitDepthKey: AppSettings.bitDepth,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    /// 録音を開始する
    /// マイクパーミッションが未許可の場合はシステムダイアログを表示
    func startRecording() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginRecording()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.beginRecording()
                    }
                } else {
                    print("[VoiceInput] マイクアクセスが拒否されました")
                }
            }
        case .denied, .restricted:
            print("[VoiceInput] マイクアクセスが許可されていません。システム設定から許可してください。")
        @unknown default:
            break
        }
    }

    /// 録音を停止してファイルURLを返す
    /// - Returns: 保存されたWAVファイルのURL（録音中でない場合はnil）
    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording, let recorder = recorder else { return nil }

        let url = recorder.url
        recorder.stop()
        isRecording = false
        self.recorder = nil

        print("[VoiceInput] 録音停止: \(url.lastPathComponent)")
        return url
    }

    // MARK: - Private

    /// 実際の録音処理を開始
    private func beginRecording() {
        let fileURL = generateFileURL()

        do {
            recorder = try AVAudioRecorder(url: fileURL, settings: audioSettings)
            recorder?.delegate = self
            recorder?.record()
            isRecording = true
            print("[VoiceInput] 録音開始: \(fileURL.lastPathComponent)")
        } catch {
            print("[VoiceInput] 録音開始エラー: \(error.localizedDescription)")
        }
    }

    /// 保存先ファイルURLを生成
    /// ~/Documents/VoiceInput/recording_yyyyMMdd_HHmmss.wav
    private func generateFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let voiceInputDir = documentsPath.appendingPathComponent(AppSettings.saveDirectoryName)

        // ディレクトリがなければ作成
        if !FileManager.default.fileExists(atPath: voiceInputDir.path) {
            try? FileManager.default.createDirectory(at: voiceInputDir, withIntermediateDirectories: true)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "recording_\(formatter.string(from: Date())).wav"

        return voiceInputDir.appendingPathComponent(fileName)
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("[VoiceInput] 録音が正常に完了しませんでした")
        }
    }
}
