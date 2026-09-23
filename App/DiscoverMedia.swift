import SwiftUI
import SwiftData
import PhotosUI
import AVKit
import UniformTypeIdentifiers

// MARK: - 视频号（本地视频）

/// 从相册导入的视频，复制到 App 目录
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = LocalFiles.directory("Channels").appending(path: UUID().uuidString + "." + ext)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

extension ChannelVideo {
    var fileURL: URL { LocalFiles.directory("Channels").appending(path: fileName) }
}

struct VideoImportSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var caption = ""
    @State private var importedURL: URL?
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $item, matching: .videos) {
                        Label(importedURL == nil ? "从相册选择视频" : "已选择，点此更换", systemImage: "video.badge.plus")
                    }
                    if loading { ProgressView("正在导入…") }
                }
                Section("描述") {
                    TextField("添加描述…", text: $caption, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle("发表视频")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        if let importedURL { try? FileManager.default.removeItem(at: importedURL) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发表") {
                        guard let importedURL else { return }
                        context.insert(ChannelVideo(fileName: importedURL.lastPathComponent,
                                                    caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(importedURL == nil)
                }
            }
            .onChange(of: item) { _, newItem in
                guard let newItem else { return }
                loading = true
                Task {
                    if let movie = try? await newItem.loadTransferable(type: PickedMovie.self) {
                        if let old = importedURL { try? FileManager.default.removeItem(at: old) }
                        importedURL = movie.url
                    }
                    loading = false
                }
            }
        }
    }
}

struct VideoThumbnail: View {
    let video: ChannelVideo
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black
            if let image { Image(uiImage: image).resizable().scaledToFill() }
        }
        .task(id: video.id) {
            if let cached = VideoThumbnailCache.cache.object(forKey: video.id.uuidString as NSString) {
                image = cached
                return
            }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video.fileURL))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 400)
            if let cg = try? await generator.image(at: .zero).image {
                let result = UIImage(cgImage: cg)
                VideoThumbnailCache.cache.setObject(result, forKey: video.id.uuidString as NSString)
                image = result
            }
        }
    }
}

enum VideoThumbnailCache {
    static let cache = NSCache<NSString, UIImage>()
}

/// 视频号入口：竖向翻页播放
struct ChannelsView: View {
    @Query(sort: \ChannelVideo.createdAt, order: .reverse) private var videos: [ChannelVideo]
    @Environment(\.dismiss) private var dismiss
    @State private var showImport = false

    var body: some View {
        ChannelsFeed(videos: videos, startID: nil, onClose: { dismiss() }, onAdd: { showImport = true })
            .toolbar(.hidden, for: .navigationBar)
            .edgeSwipeBack()
            .sheet(isPresented: $showImport) { VideoImportSheet() }
    }
}

/// 从"作品"点开时全屏播放
struct ChannelsPlayerView: View {
    let videos: [ChannelVideo]
    let startID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ChannelsFeed(videos: videos, startID: startID, onClose: { dismiss() }, onAdd: nil)
    }
}

struct ChannelsFeed: View {
    let videos: [ChannelVideo]
    let startID: UUID?
    var onClose: () -> Void
    var onAdd: (() -> Void)?

    @State private var currentID: UUID?
    @State private var tab = "推荐"

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if videos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle.on.rectangle").font(.system(size: 44, weight: .light))
                    Text("还没有视频").font(.system(size: 17, weight: .medium))
                    Text("从相册选择视频发表，本地保存、仅自己可见").font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                    if let onAdd {
                        Button("发表视频", action: onAdd).buttonStyle(.borderedProminent).tint(Color.brand)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(videos) { video in
                            ChannelVideoPage(video: video, isCurrent: currentID == video.id)
                                .containerRelativeFrame([.horizontal, .vertical])
                                .id(video.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentID)
                .ignoresSafeArea()
            }
            topBar
        }
        .onAppear { if currentID == nil { currentID = startID ?? videos.first?.id } }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("返回")
            Spacer()
            HStack(spacing: 22) {
                ForEach(["关注", "推荐"], id: \.self) { name in
                    Button(name) { tab = name }
                        .font(.system(size: 17, weight: tab == name ? .semibold : .regular))
                        .opacity(tab == name ? 1 : 0.6)
                }
            }
            Spacer()
            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle").font(.system(size: 20)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("发表视频")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
    }
}

private struct ChannelVideoPage: View {
    @Bindable var video: ChannelVideo
    let isCurrent: Bool
    @Query(filter: #Predicate<Contact> { $0.isMe == true }) private var meList: [Contact]
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var paused = false

    var body: some View {
        ZStack(alignment: .bottom) {
            PlayerLayerView(player: player)
                .contentShape(Rectangle())
                .onTapGesture {
                    paused.toggle()
                    paused ? player?.pause() : player?.play()
                }
            if paused {
                Image(systemName: "play.fill").font(.system(size: 52)).foregroundStyle(.white.opacity(0.8))
                    .frame(maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        AvatarView(contact: meList.first, size: 32)
                        Text(meList.first?.name ?? "我").font(.system(size: 16, weight: .semibold))
                    }
                    if !video.caption.isEmpty {
                        Text(video.caption).font(.system(size: 15)).lineLimit(3)
                    }
                    Text(RelativeTime.label(video.createdAt)).font(.system(size: 12)).opacity(0.6)
                }
                Spacer()
                VStack(spacing: 4) {
                    Button { video.liked.toggle() } label: {
                        Image(systemName: video.liked ? "heart.fill" : "heart")
                            .font(.system(size: 30))
                            .foregroundStyle(video.liked ? Color(hex: 0xFA5151) : .white)
                    }
                    Text(video.liked ? "1" : "赞").font(.system(size: 12))
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 50)
        }
        .onAppear {
            guard player == nil else { return }
            let queue = AVQueuePlayer()
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: video.fileURL))
            player = queue
            if isCurrent { queue.play() }
        }
        .onChange(of: isCurrent) { _, current in
            if current { paused = false; player?.play() } else { player?.pause() }
        }
        .onDisappear { player?.pause() }
    }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?

    final class LayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {
        view.playerLayer.player = player
    }
}

// MARK: - 直播（相机预览模拟开播）

struct LiveView: View {
    @State private var broadcasting = false

    var body: some View {
        VStack(spacing: 0) {
            ContentUnavailableView {
                Label("暂无正在直播的朋友", systemImage: "circle.circle")
            } description: {
                Text("可以用前置相机体验开播界面，画面只在本机显示，不会上传。")
            } actions: {
                Button("发起直播") { broadcasting = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: 0xFA5151))
                    .accessibilityIdentifier("live.start")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.chatBackground)
        .navigationTitle("直播")
        .weChatNavigation()
        .fullScreenCover(isPresented: $broadcasting) { LiveBroadcastView() }
    }
}

struct LiveBroadcastView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Contact> { $0.isMe == true }) private var meList: [Contact]
    @State private var start = Date()
    @State private var likes = 0
    @State private var comments: [String] = []
    @State private var draft = ""
    @State private var confirmEnd = false

    var body: some View {
        ZStack {
            CameraPreview(position: .front).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        AvatarView(contact: meList.first, size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(meList.first?.name ?? "我").font(.system(size: 14, weight: .semibold))
                            Text("本场点赞 \(likes)").font(.system(size: 11)).opacity(0.8)
                        }
                    }
                    .padding(.trailing, 12).padding(4)
                    .background(.black.opacity(0.35), in: Capsule())
                    Spacer()
                    TimelineView(.periodic(from: start, by: 1)) { context in
                        Text(Self.format(context.date.timeIntervalSince(start)))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color(hex: 0xFA5151), in: Capsule())
                    }
                    Button { confirmEnd = true } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34).background(.black.opacity(0.35), in: Circle())
                    }
                    .accessibilityLabel("结束直播")
                }
                .padding(.horizontal, 12)
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("直播画面只在本机显示，未上传").font(.system(size: 13)).foregroundStyle(Color(hex: 0xFFC300))
                    ForEach(comments.suffix(6).indices, id: \.self) { index in
                        Text("我：" + comments.suffix(6)[index]).font(.system(size: 14))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.black.opacity(0.35), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                HStack(spacing: 10) {
                    TextField("说点什么…", text: $draft)
                        .padding(.horizontal, 14).frame(height: 38)
                        .background(.black.opacity(0.35), in: Capsule())
                        .submitLabel(.send)
                        .onSubmit {
                            let text = draft.trimmingCharacters(in: .whitespaces)
                            if !text.isEmpty { comments.append(text) }
                            draft = ""
                        }
                    Button { likes += 1 } label: {
                        Image(systemName: "heart.fill").font(.system(size: 20)).foregroundStyle(Color(hex: 0xFA5151))
                            .frame(width: 38, height: 38).background(.black.opacity(0.35), in: Circle())
                    }
                    .accessibilityLabel("点赞")
                }
                .padding(12)
            }
            .foregroundStyle(.white)
        }
        .background(Color.black)
        .confirmationDialog("结束直播？本场时长 \(Self.format(Date().timeIntervalSince(start)))", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("结束直播", role: .destructive) { dismiss() }
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// 相机实时预览；没有相机或未授权时显示提示
struct CameraPreview: UIViewRepresentable {
    var position: AVCaptureDevice.Position = .front

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        let session = AVCaptureSession()
        let label = UILabel()
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = UIColor(white: 0.12, alpha: 1)
        view.previewLayer.session = view.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.label.text = "相机不可用"
        view.label.textColor = UIColor(white: 1, alpha: 0.6)
        view.label.isHidden = true
        view.label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(view.label)
        NSLayoutConstraint.activate([
            view.label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            view.label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        let session = view.session
        let position = position
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted,
                  let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                DispatchQueue.main.async { view.label.isHidden = false }
                return
            }
            session.beginConfiguration()
            if session.canAddInput(input) { session.addInput(input) }
            session.commitConfiguration()
            session.startRunning()
        }
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        let session = view.session
        DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
    }
}

// MARK: - 听一听（本地音乐）

extension AudioTrack {
    var fileURL: URL { LocalFiles.directory("Music").appending(path: fileName) }
}

@MainActor
final class MusicPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = MusicPlayer()

    @Published private(set) var currentID: UUID?
    @Published private(set) var currentTitle = ""
    @Published private(set) var isPlaying = false
    @Published var progress: Double = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func play(_ track: AudioTrack) {
        if currentID == track.id {
            toggle()
            return
        }
        VoicePlayer.shared.stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: track.fileURL)
        player?.delegate = self
        player?.play()
        currentID = track.id
        currentTitle = track.title
        isPlaying = player?.isPlaying ?? false
        startTimer()
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying { player.pause() } else { player.play() }
        isPlaying = player.isPlaying
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        player.currentTime = fraction * player.duration
        progress = fraction
    }

    func stop() {
        player?.stop()
        player = nil
        currentID = nil
        isPlaying = false
        timer?.invalidate()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.progress = player.currentTime / player.duration
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0
        }
    }
}

struct ListenView: View {
    @Query(sort: \AudioTrack.addedAt, order: .reverse) private var tracks: [AudioTrack]
    @Environment(\.modelContext) private var context
    @ObservedObject private var player = MusicPlayer.shared
    @State private var importing = false

    var body: some View {
        List {
            ForEach(tracks) { track in
                Button { player.play(track) } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xFA5151).opacity(0.12))
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: player.currentID == track.id && player.isPlaying ? "waveform" : "music.note")
                                .foregroundStyle(Color(hex: 0xFA5151)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title).foregroundStyle(player.currentID == track.id ? Color.brand : .primary).lineLimit(1)
                            Text(LiveBroadcastView.format(track.duration)).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("删除", role: .destructive) {
                        if player.currentID == track.id { player.stop() }
                        try? FileManager.default.removeItem(at: track.fileURL)
                        context.delete(track)
                        try? context.save()
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if tracks.isEmpty {
                ContentUnavailableView {
                    Label("还没有音乐", systemImage: "music.note")
                } description: {
                    Text("从\u{201C}文件\u{201D}导入 mp3、m4a 等音频，在本机播放")
                } actions: {
                    Button("导入音乐") { importing = true }.buttonStyle(.borderedProminent).tint(Color.brand)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { if player.currentID != nil { miniPlayer } }
        .navigationTitle("听一听")
        .weChatNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { importing = true } label: { Image(systemName: "plus.circle") }.accessibilityLabel("导入音乐")
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            Task { await importFiles(urls) }
        }
    }

    private var miniPlayer: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(get: { player.progress }, set: { player.seek(to: $0) }))
                .tint(Color.brand)
            HStack {
                Text(player.currentTitle).font(.system(size: 15)).lineLimit(1)
                Spacer()
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 34))
                        .foregroundStyle(Color.brand)
                }
                .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func importFiles(_ urls: [URL]) async {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let name = UUID().uuidString + "." + (url.pathExtension.isEmpty ? "m4a" : url.pathExtension)
            let destination = LocalFiles.directory("Music").appending(path: name)
            guard (try? FileManager.default.copyItem(at: url, to: destination)) != nil else { continue }
            let duration = (try? await AVURLAsset(url: destination).load(.duration).seconds) ?? 0
            context.insert(AudioTrack(title: url.deletingPathExtension().lastPathComponent, fileName: name,
                                      duration: duration.isFinite ? duration : 0))
        }
        try? context.save()
    }
}
