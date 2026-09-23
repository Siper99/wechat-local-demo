import SwiftUI
import SwiftData
import AVFoundation
import UserNotifications

// MARK: - 语音消息：录音

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var level: Float = 0
    private var recorder: AVAudioRecorder?
    private var meter: Timer?
    private var startedAt = Date()

    private var fileURL: URL { FileManager.default.temporaryDirectory.appending(path: "voice.m4a") }

    /// 请求麦克风权限并开始录音；无权限返回 false
    func start() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        MusicPlayer.shared.stop()
        VoicePlayer.shared.stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        guard let recorder = try? AVAudioRecorder(url: fileURL, settings: settings) else { return false }
        recorder.isMeteringEnabled = true
        recorder.record(forDuration: 60)
        self.recorder = recorder
        startedAt = Date()
        isRecording = true
        meter = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                self.level = max(0, (recorder.averagePower(forChannel: 0) + 50) / 50)
            }
        }
        return true
    }

    /// 结束录音，返回音频数据和时长；cancel 或太短时返回 nil
    func stop(cancel: Bool) -> (Data, Double)? {
        meter?.invalidate()
        let duration = Date().timeIntervalSince(startedAt)
        recorder?.stop()
        recorder = nil
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard !cancel, duration >= 1, let data = try? Data(contentsOf: fileURL) else { return nil }
        return (data, min(duration, 60))
    }
}

// MARK: - 语音消息：播放

@MainActor
final class VoicePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = VoicePlayer()
    @Published private(set) var playingID: UUID?
    private var player: AVAudioPlayer?

    func toggle(_ message: Message) {
        if playingID == message.id {
            stop()
            return
        }
        stop()
        guard let data = message.audioData else { return }
        MusicPlayer.shared.stop()
        // 设置 → 聊天 → 使用听筒播放语音
        let earpiece = UserDefaults.standard.bool(forKey: "voiceUseEarpiece")
        try? AVAudioSession.sharedInstance().setCategory(earpiece ? .playAndRecord : .playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(data: data)
        player?.delegate = self
        if player?.play() == true { playingID = message.id }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playingID = nil }
    }
}

/// 按住说话时屏幕中间的提示框
struct VoiceRecordingHUD: View {
    let level: Float
    let willCancel: Bool

    var body: some View {
        VStack(spacing: 12) {
            if willCancel {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 40))
            } else {
                HStack(alignment: .center, spacing: 3) {
                    ForEach(0..<9, id: \.self) { index in
                        Capsule().frame(width: 4, height: 8 + CGFloat(level) * CGFloat([10, 18, 26, 34, 40, 34, 26, 18, 10][index]))
                    }
                }
                .frame(height: 50)
            }
            Text(willCancel ? "松开手指，取消发送" : "手指上滑，取消发送")
                .font(.system(size: 13))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(willCancel ? Color(hex: 0xFA5151) : .clear, in: RoundedRectangle(cornerRadius: 3))
        }
        .foregroundStyle(.white)
        .frame(width: 160, height: 150)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        .animation(.easeOut(duration: 0.1), value: level)
    }
}

// MARK: - 气泡：语音、名片、通话记录

struct VoiceBubble: View {
    let message: Message
    @ObservedObject private var player = VoicePlayer.shared

    private var playing: Bool { player.playingID == message.id }
    private var seconds: Int { max(1, Int(message.duration.rounded())) }
    private var width: CGFloat { min(210, 70 + CGFloat(seconds) * 4) }

    var body: some View {
        HStack(spacing: 8) {
            if message.fromMe {
                Spacer(minLength: 0)
                Text("\(seconds)″")
                wave.scaleEffect(x: -1)
            } else {
                wave
                Text("\(seconds)″")
                Spacer(minLength: 0)
            }
        }
        .font(.system(size: 16))
        .foregroundStyle(message.fromMe ? Color.textOnMe : Color.textOnOther)
        .padding(.leading, message.fromMe ? 12 : 12 + BubbleShape.arrowWidth)
        .padding(.trailing, message.fromMe ? 12 + BubbleShape.arrowWidth : 12)
        .frame(width: width, height: 40)
        .background(BubbleShape(isMe: message.fromMe).fill(message.fromMe ? Color.bubbleMe : Color.bubbleOther))
        .contentShape(BubbleShape(isMe: message.fromMe))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("语音 \(seconds) 秒")
        .accessibilityAddTraits(.isButton)
    }

    private var wave: some View {
        Image(systemName: "wave.3.right")
            .font(.system(size: 17, weight: .medium))
            .symbolEffect(.variableColor.iterative, isActive: playing)
    }
}

struct CardBubble: View {
    let message: Message
    let contact: Contact?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AvatarView(name: message.text, data: contact?.avatarData, size: 44)
                Text(message.text).font(.system(size: 17)).foregroundStyle(Color.textOnOther).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(12)
            Divider().padding(.horizontal, 12)
            Text("个人名片").font(.system(size: 12)).foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .frame(width: 230)
        .background(Color.bubbleOther, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 5))
    }
}

struct CallBubble: View {
    let message: Message
    var body: some View {
        HStack(spacing: 6) {
            if !message.fromMe { icon }
            Text(message.text)
            if message.fromMe { icon }
        }
        .font(.system(size: 17))
        .foregroundStyle(message.fromMe ? Color.textOnMe : Color.textOnOther)
        .padding(.vertical, 10)
        .padding(.leading, message.fromMe ? 12 : 12 + BubbleShape.arrowWidth)
        .padding(.trailing, message.fromMe ? 12 + BubbleShape.arrowWidth : 12)
        .frame(minHeight: 40)
        .background(BubbleShape(isMe: message.fromMe).fill(message.fromMe ? Color.bubbleMe : Color.bubbleOther))
    }

    private var icon: some View {
        Image(systemName: message.isVideoCall ? "video" : "phone").font(.system(size: 15))
    }
}

// MARK: - 选择名片

struct CardPickerSheet: View {
    var title = "选择名片"
    var onPick: (Contact) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Contact> { $0.isMe == false && $0.isSystem == false }, sort: \Contact.name)
    private var contacts: [Contact]

    var body: some View {
        NavigationStack {
            List(contacts) { contact in
                Button {
                    onPick(contact)
                    dismiss()
                } label: {
                    HStack(spacing: 12) { AvatarView(contact: contact, size: 36); Text(contact.name).foregroundStyle(.primary) }
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}

// MARK: - 音视频通话（本地模拟界面）

struct CallRequest: Identifiable {
    let id = UUID()
    let video: Bool
}

struct CallView: View {
    let peerName: String
    let peerAvatar: Data?
    let video: Bool
    /// 结束时回传通话时长（秒）；未接通为 nil
    var onEnd: (TimeInterval?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var connectedAt: Date?
    @State private var muted = false
    @State private var speaker = false
    @State private var cameraOff = false

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("本地模拟通话，不会呼叫对方").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 8)
                Spacer().frame(height: 40)
                AvatarView(name: peerName, data: peerAvatar, size: 96)
                Text(peerName).font(.system(size: 24, weight: .medium))
                if let connectedAt {
                    TimelineView(.periodic(from: connectedAt, by: 1)) { context in
                        Text(LiveBroadcastView.format(context.date.timeIntervalSince(connectedAt)))
                            .font(.system(size: 16).monospacedDigit())
                    }
                } else {
                    Text(video ? "正在等待对方接受邀请…" : "正在呼叫…").font(.system(size: 15)).opacity(0.8)
                }
                Spacer()
                HStack(spacing: 40) {
                    if video {
                        control(cameraOff ? "摄像头已关" : "摄像头", cameraOff ? "video.slash.fill" : "video.fill", active: !cameraOff) {
                            cameraOff.toggle()
                        }
                    } else {
                        control("麦克风", muted ? "mic.slash.fill" : "mic.fill", active: !muted) { muted.toggle() }
                    }
                    Button {
                        let duration = connectedAt.map { Date().timeIntervalSince($0) }
                        onEnd(duration)
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.down.fill").font(.system(size: 28))
                                .frame(width: 68, height: 68).background(Color(hex: 0xFA5151), in: Circle())
                            Text(connectedAt == nil ? "取消" : "挂断").font(.system(size: 13))
                        }
                    }
                    .accessibilityIdentifier("call.hangup")
                    control("扬声器", speaker ? "speaker.wave.3.fill" : "speaker.fill", active: speaker) { speaker.toggle() }
                }
                .padding(.bottom, 40)
            }
            .foregroundStyle(.white)
            if video && connectedAt != nil && !cameraOff {
                CameraPreview(position: .front)
                    .frame(width: 110, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 40).padding(.trailing, 16)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { connectedAt = Date() }
        }
    }

    private var background: some View {
        ZStack {
            if let peerAvatar, let image = UIImage(data: peerAvatar) {
                Image(uiImage: image).resizable().scaledToFill().blur(radius: 40)
            }
            Color.black.opacity(0.65)
        }
    }

    private func control(_ title: String, _ symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 24))
                    .foregroundStyle(active ? .black : .white)
                    .frame(width: 68, height: 68)
                    .background(active ? Color.white : Color.white.opacity(0.2), in: Circle())
                Text(title).font(.system(size: 13))
            }
        }
    }
}

// MARK: - 新消息通知（模拟回复在后台到达时）

enum LocalNotifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    @MainActor
    static func notifyIfNeeded(title: String, body: String) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "notifyNewMessage") as? Bool ?? true,
              UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = defaults.object(forKey: "notifyShowDetail") as? Bool ?? true ? body : "你收到了一条新消息"
        if defaults.object(forKey: "notifySound") as? Bool ?? true { content.sound = .default }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
