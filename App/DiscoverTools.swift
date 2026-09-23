import SwiftUI
import SwiftData
import PhotosUI
import VisionKit
import AVFoundation
import MapKit
import CoreLocation

// MARK: - 扫一扫

struct ScanView: View {
    @State private var result: ScanResult?
    @State private var photoItem: PhotosPickerItem?
    @State private var cameraAllowed: Bool?
    @State private var notFound = false

    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && cameraAllowed == true
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if scannerAvailable {
                QRScannerView { payload in
                    if result == nil { result = ScanResult(text: payload) }
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder").font(.system(size: 60, weight: .light))
                    Text(cameraAllowed == false ? "未获得相机权限，可在系统设置中开启" : "当前设备不支持相机扫码")
                        .font(.system(size: 15))
                    Text("可以从相册选择含二维码的图片识别").font(.system(size: 13)).opacity(0.6)
                }
                .foregroundStyle(.white)
            }
            VStack {
                Spacer()
                Text("扫二维码 / 条码").font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 60) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        VStack(spacing: 6) {
                            Image(systemName: "photo").font(.system(size: 22))
                                .frame(width: 50, height: 50).background(.white.opacity(0.15), in: Circle())
                            Text("相册").font(.system(size: 12))
                        }
                    }
                    .accessibilityIdentifier("scan.album")
                    NavigationLink { MyQRCodeView() } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "qrcode").font(.system(size: 22))
                                .frame(width: 50, height: 50).background(.white.opacity(0.15), in: Circle())
                            Text("我的二维码").font(.system(size: 12))
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("扫一扫")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: cameraAllowed = true
            case .notDetermined: cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
            default: cameraAllowed = false
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
                   let text = QRCode.decode(image) {
                    result = ScanResult(text: text)
                } else {
                    notFound = true
                }
                photoItem = nil
            }
        }
        .sheet(item: $result) { ScanResultSheet(result: $0) }
        .alert("未发现二维码", isPresented: $notFound) { Button("知道了", role: .cancel) {} }
    }
}

struct ScanResult: Identifiable {
    let id = UUID()
    let text: String
}

private struct ScanResultSheet: View {
    let result: ScanResult
    @Environment(\.dismiss) private var dismiss
    @State private var web: IdentifiedURL?

    private var url: URL? {
        guard let url = URL(string: result.text), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            List {
                Section(result.text.hasPrefix("wechat-local-demo://") ? "本地演示二维码" : "识别结果") {
                    Text(result.text).textSelection(.enabled)
                }
                Section {
                    if let url {
                        Button("打开链接") { web = IdentifiedURL(url: url) }
                    }
                    Button("复制") { UIPasteboard.general.string = result.text; dismiss() }
                }
            }
            .navigationTitle("扫描结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(item: $web) { SafariView(url: $0.url).ignoresSafeArea() }
        }
        .presentationDetents([.medium])
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    var onFound: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(recognizedDataTypes: [.barcode()], qualityLevel: .balanced,
                                                   isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        DispatchQueue.main.async { try? controller.startScanning() }
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.onFound = onFound
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onFound: (String) -> Void
        init(onFound: @escaping (String) -> Void) { self.onFound = onFound }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onFound(payload)
                    return
                }
            }
        }
    }
}

// MARK: - 看一看 / 公众号文章

struct TopStoriesView: View {
    @Query(sort: \Article.publishedAt, order: .reverse) private var articles: [Article]
    @State private var tab = "精选"

    private var shown: [Article] { tab == "精选" ? articles : articles.filter(\.watching) }

    var body: some View {
        List {
            Picker("", selection: $tab) {
                Text("精选").tag("精选")
                Text("在看").tag("在看")
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            ForEach(shown) { article in
                NavigationLink { ArticleView(article: article) } label: { ArticleRow(article: article) }
            }
        }
        .listStyle(.plain)
        .overlay {
            if shown.isEmpty {
                ContentUnavailableView(tab == "精选" ? "暂无文章" : "还没有\u{201C}在看\u{201D}的文章", systemImage: "doc.text",
                                       description: Text(tab == "精选" ? "关注的公众号发布文章后会显示在这里" : "在文章底部点\u{201C}在看\u{201D}")).allowsHitTesting(false)
            }
        }
        .navigationTitle("看一看")
        .weChatNavigation()
    }
}

struct ArticleRow: View {
    let article: Article
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title).font(.system(size: 17, weight: .medium)).lineLimit(2).foregroundStyle(.primary)
                Text("\(article.account?.name ?? "公众号")  \(RelativeTime.label(article.publishedAt))")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: article.account?.colorHex ?? 0x1485EE).opacity(0.15))
                .frame(width: 72, height: 72)
                .overlay(Image(systemName: article.account?.symbol ?? "doc.text")
                    .font(.system(size: 26)).foregroundStyle(Color(hex: article.account?.colorHex ?? 0x1485EE)))
        }
        .padding(.vertical, 6)
    }
}

struct ArticleView: View {
    @Bindable var article: Article
    @Environment(\.modelContext) private var context
    @State private var savedToFavorites = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(article.title).font(.system(size: 22, weight: .bold))
                HStack(spacing: 8) {
                    Text(article.account?.name ?? "公众号").foregroundStyle(Color.linkBlue)
                    Text(ChatTime.chatLabel(article.publishedAt)).foregroundStyle(.secondary)
                }
                .font(.system(size: 14))
                ForEach(article.body.components(separatedBy: "\n\n"), id: \.self) { paragraph in
                    Text(paragraph).font(.system(size: 17)).lineSpacing(7)
                }
                Text("本文为本地演示内容").font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 20)
            }
            .padding(20)
        }
        .background(Color.cellBackground)
        .safeAreaInset(edge: .bottom) {
            HStack {
                ShareLink(item: article.title + "\n\n" + article.body) {
                    Label("分享", systemImage: "arrowshape.turn.up.right")
                }
                Spacer()
                Button {
                    guard !savedToFavorites else { return }
                    context.insert(Note(text: "《\(article.title)》\n\n\(article.body)"))
                    try? context.save()
                    savedToFavorites = true
                } label: {
                    Label(savedToFavorites ? "已收藏" : "收藏", systemImage: savedToFavorites ? "star.fill" : "star")
                }
                Spacer()
                Button { article.liked.toggle() } label: {
                    Label("赞", systemImage: article.liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                Spacer()
                Button { article.watching.toggle() } label: {
                    Label("在看", systemImage: article.watching ? "heart.circle.fill" : "heart.circle")
                }
                .accessibilityIdentifier("article.watching")
            }
            .font(.system(size: 14))
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .navigationTitle("")
        .weChatNavigation()
    }
}

// MARK: - 搜一搜（本机全局搜索 + 网页搜索）

struct SearchHubView: View {
    @Query private var contacts: [Contact]
    @Query private var conversations: [Conversation]
    @Query(sort: \Message.sentAt, order: .reverse) private var messages: [Message]
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]
    @Query(sort: \Article.publishedAt, order: .reverse) private var articles: [Article]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @State private var query = ""
    @State private var web: IdentifiedURL?
    @FocusState private var focused: Bool

    private var q: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        List {
            if q.isEmpty {
                Section("搜索指定内容") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 18) {
                        ForEach(["朋友圈", "文章", "公众号", "聊天记录", "联系人", "笔记"], id: \.self) { name in
                            Text(name).font(.system(size: 15)).foregroundStyle(Color.linkBlue)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                let matchedContacts = contacts.filter { !$0.isMe && $0.name.localizedStandardContains(q) }
                let matchedGroups = conversations.filter { $0.isGroup && $0.title.localizedStandardContains(q) }
                let matchedMessages = Array(messages.filter { $0.kind != .system && $0.preview.localizedStandardContains(q) }.prefix(20))
                let matchedMoments = moments.filter { $0.text.localizedStandardContains(q) }
                let matchedArticles = articles.filter { $0.title.localizedStandardContains(q) || $0.body.localizedStandardContains(q) }
                let matchedNotes = notes.filter { $0.text.localizedStandardContains(q) }
                if !matchedContacts.isEmpty {
                    Section("联系人") {
                        ForEach(matchedContacts) { contact in
                            NavigationLink { ContactDetailView(contact: contact) } label: {
                                HStack(spacing: 10) { AvatarView(contact: contact, size: 36); Text(contact.name) }
                            }
                        }
                    }
                }
                if !matchedGroups.isEmpty {
                    Section("群聊") {
                        ForEach(matchedGroups) { group in
                            NavigationLink { ChatView(conversation: group) } label: {
                                HStack(spacing: 10) { ConversationAvatar(conversation: group, size: 36); Text(group.title) }
                            }
                        }
                    }
                }
                if !matchedMessages.isEmpty {
                    Section("聊天记录") {
                        ForEach(matchedMessages) { message in
                            if let conversation = message.conversation {
                                NavigationLink { ChatView(conversation: conversation) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(conversation.title).font(.system(size: 15))
                                        Text(message.preview).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
                if !matchedMoments.isEmpty {
                    Section("朋友圈") {
                        ForEach(matchedMoments) { moment in
                            NavigationLink { MomentsView(authorID: moment.authorID, title: moment.authorName) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(moment.authorName).font(.system(size: 15)).foregroundStyle(Color.linkBlue)
                                    Text(moment.text).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                    }
                }
                if !matchedArticles.isEmpty {
                    Section("文章") {
                        ForEach(matchedArticles) { article in
                            NavigationLink { ArticleView(article: article) } label: { ArticleRow(article: article) }
                        }
                    }
                }
                if !matchedNotes.isEmpty {
                    Section("笔记") {
                        ForEach(matchedNotes) { note in
                            NavigationLink { NoteEditorView(note: note) } label: { Text(note.text).lineLimit(2) }
                        }
                    }
                }
                Section {
                    Button {
                        if let url = URL.webSearch(q) { web = IdentifiedURL(url: url) }
                    } label: {
                        Label("搜索网页：\(q)", systemImage: "globe")
                    }
                    .accessibilityIdentifier("search.web")
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索", text: $query)
                    .focused($focused)
                    .submitLabel(.search)
                    .accessibilityIdentifier("searchHub.field")
                    .testingKeyboard()
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color.inputField, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.chatBackground)
        }
        .navigationTitle("搜一搜")
        .weChatNavigation()
        .onAppear { focused = true }
        .sheet(item: $web) { SafariView(url: $0.url).ignoresSafeArea() }
    }
}

// MARK: - 附近的人

@MainActor
final class LocationModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        status = manager.authorizationStatus
    }

    func request() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.status = status }
    }
}

struct NearbyView: View {
    @StateObject private var location = LocationModel()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    private var allowed: Bool { location.status == .authorizedWhenInUse || location.status == .authorizedAlways }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $position) {
                UserAnnotation()
            }
            .mapControls { MapUserLocationButton() }
            .frame(height: 300)
            List {
                Section {
                    if allowed {
                        Label("附近暂无其他使用本地演示的用户", systemImage: "person.wave.2")
                            .foregroundStyle(.secondary)
                    } else if location.status == .denied || location.status == .restricted {
                        Label("未获得定位权限，可在系统设置中开启", systemImage: "location.slash")
                    } else {
                        Button { location.request() } label: { Label("开启定位查看附近", systemImage: "location") }
                    }
                } footer: {
                    Text("位置只用于在本机地图上显示，不会上传。")
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("附近的人")
        .weChatNavigation()
        .onAppear { location.request() }
    }
}

// MARK: - 游戏（2048）

struct GamesView: View {
    @AppStorage("game2048Best") private var best = 0

    var body: some View {
        List {
            Section("我的游戏") {
                NavigationLink { Game2048View() } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xEDC22E)).frame(width: 52, height: 52)
                            .overlay(Text("2048").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("2048").font(.system(size: 17, weight: .medium))
                            Text("最高分 \(best)").font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityIdentifier("games.2048")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("游戏")
        .weChatNavigation()
    }
}

struct Game2048View: View {
    @AppStorage("game2048Best") private var best = 0
    @State private var board = Board2048()

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                scoreBox("分数", board.score)
                scoreBox("最高", best)
                Spacer()
                Button("新游戏") { withAnimation { board = Board2048() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: 0x8F7A66))
            }
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xBBADA0))
                VStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { column in tile(board.cells[row][column]) }
                        }
                    }
                }
                .padding(8)
                if board.isOver {
                    RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.6))
                    VStack(spacing: 12) {
                        Text("游戏结束").font(.system(size: 28, weight: .bold)).foregroundStyle(Color(hex: 0x776E65))
                        Button("再来一局") { withAnimation { board = Board2048() } }
                            .buttonStyle(.borderedProminent).tint(Color(hex: 0x8F7A66))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .gesture(DragGesture(minimumDistance: 20).onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                let direction: Board2048.Direction = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
                withAnimation(.easeOut(duration: 0.12)) { board.move(direction) }
                best = max(best, board.score)
            })
            Text("在方块区域上下左右滑动，相同数字合并").font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .background(Color(hex: 0xFAF8EF))
        .navigationTitle("2048")
        .weChatNavigation()
    }

    private func scoreBox(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex: 0xEEE4DA))
            Text("\(value)").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
        }
        .frame(minWidth: 70)
        .padding(.vertical, 6)
        .background(Color(hex: 0xBBADA0), in: RoundedRectangle(cornerRadius: 6))
    }

    private func tile(_ value: Int) -> some View {
        let colors: [Int: (Int, Int)] = [
            2: (0xEEE4DA, 0x776E65), 4: (0xEDE0C8, 0x776E65), 8: (0xF2B179, 0xFFFFFF), 16: (0xF59563, 0xFFFFFF),
            32: (0xF67C5F, 0xFFFFFF), 64: (0xF65E3B, 0xFFFFFF), 128: (0xEDCF72, 0xFFFFFF), 256: (0xEDCC61, 0xFFFFFF),
            512: (0xEDC850, 0xFFFFFF), 1024: (0xEDC53F, 0xFFFFFF), 2048: (0xEDC22E, 0xFFFFFF),
        ]
        let (background, foreground) = colors[value] ?? (value == 0 ? (0xCDC1B4, 0x776E65) : (0x3C3A32, 0xFFFFFF))
        return RoundedRectangle(cornerRadius: 5)
            .fill(Color(hex: background))
            .overlay {
                if value > 0 {
                    Text("\(value)")
                        .font(.system(size: value < 100 ? 32 : value < 1000 ? 26 : 20, weight: .bold))
                        .foregroundStyle(Color(hex: foreground))
                }
            }
            .aspectRatio(1, contentMode: .fit)
    }
}

struct Board2048 {
    enum Direction { case up, down, left, right }
    var cells: [[Int]] = Array(repeating: Array(repeating: 0, count: 4), count: 4)
    var score = 0

    init() {
        spawn()
        spawn()
    }

    var isOver: Bool {
        for r in 0..<4 {
            for c in 0..<4 {
                if cells[r][c] == 0 { return false }
                if c < 3 && cells[r][c] == cells[r][c + 1] { return false }
                if r < 3 && cells[r][c] == cells[r + 1][c] { return false }
            }
        }
        return true
    }

    mutating func move(_ direction: Direction) {
        let before = cells
        for index in 0..<4 {
            var line: [Int]
            switch direction {
            case .left, .right: line = cells[index]
            case .up, .down: line = (0..<4).map { cells[$0][index] }
            }
            if direction == .right || direction == .down { line.reverse() }
            line = merge(line)
            if direction == .right || direction == .down { line.reverse() }
            switch direction {
            case .left, .right: cells[index] = line
            case .up, .down: for r in 0..<4 { cells[r][index] = line[r] }
            }
        }
        if cells != before { spawn() }
    }

    /// 向左合并一行
    private mutating func merge(_ line: [Int]) -> [Int] {
        var values = line.filter { $0 != 0 }
        var result: [Int] = []
        while !values.isEmpty {
            let first = values.removeFirst()
            if let next = values.first, next == first {
                values.removeFirst()
                result.append(first * 2)
                score += first * 2
            } else {
                result.append(first)
            }
        }
        return result + Array(repeating: 0, count: 4 - result.count)
    }

    private mutating func spawn() {
        var empty: [(Int, Int)] = []
        for r in 0..<4 { for c in 0..<4 where cells[r][c] == 0 { empty.append((r, c)) } }
        guard let (r, c) = empty.randomElement() else { return }
        cells[r][c] = Int.random(in: 0..<10) == 0 ? 4 : 2
    }
}

// MARK: - 小程序（内置工具 + 自定义网页）

struct MiniProgramsView: View {
    @Query(sort: \MiniApp.lastUsed, order: .reverse) private var apps: [MiniApp]
    @Environment(\.modelContext) private var context
    @State private var showAdd = false
    @State private var web: IdentifiedURL?

    var body: some View {
        List {
            Section("内置小程序") {
                NavigationLink { CalculatorView() } label: { builtIn("计算器", "plus.forwardslash.minus", 0xFA9D3B) }
                    .accessibilityIdentifier("mini.calculator")
                NavigationLink { NotesListView() } label: { builtIn("记事本", "note.text", 0xFFC300) }
                NavigationLink { Game2048View() } label: { builtIn("2048", "square.grid.2x2", 0xEDC22E) }
            }
            Section {
                ForEach(apps) { app in
                    Button {
                        app.lastUsed = .now
                        if let url = URL.userInput(app.urlString) { web = IdentifiedURL(url: url) }
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(AvatarView.color(for: app.name)).frame(width: 40, height: 40)
                                .overlay(Text(String(app.name.prefix(1))).foregroundStyle(.white))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name).foregroundStyle(.primary)
                                Text(app.urlString).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .swipeActions {
                        Button("删除", role: .destructive) {
                            context.delete(app)
                            try? context.save()
                        }
                    }
                }
                Button { showAdd = true } label: { Label("添加网页小程序", systemImage: "plus") }
            } header: {
                Text("我的小程序")
            } footer: {
                Text("网页小程序在应用内浏览器打开。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("小程序")
        .weChatNavigation()
        .sheet(isPresented: $showAdd) { AddMiniAppSheet() }
        .sheet(item: $web) { SafariView(url: $0.url).ignoresSafeArea() }
    }

    private func builtIn(_ name: String, _ symbol: String, _ color: Int) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Color(hex: color)).frame(width: 40, height: 40)
                .overlay(Image(systemName: symbol).foregroundStyle(.white))
            Text(name)
        }
    }
}

private struct AddMiniAppSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && URL.userInput(address) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("名称", text: $name)
                TextField("网址，如 example.com", text: $address)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .navigationTitle("添加小程序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        context.insert(MiniApp(name: name.trimmingCharacters(in: .whitespaces),
                                               urlString: address.trimmingCharacters(in: .whitespaces)))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct NotesListView: View {
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var context
    @State private var editing: Note?

    var body: some View {
        List {
            ForEach(notes) { note in
                Button { editing = note } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.text.isEmpty ? "空笔记" : note.text).lineLimit(2).foregroundStyle(.primary)
                        Text(ChatTime.chatLabel(note.updatedAt)).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                offsets.map { notes[$0] }.forEach { context.delete($0) }
                try? context.save()
            }
        }
        .overlay { if notes.isEmpty { ContentUnavailableView("暂无笔记", systemImage: "note.text").allowsHitTesting(false) } }
        .navigationTitle("记事本")
        .weChatNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let note = Note(text: "")
                    context.insert(note)
                    editing = note
                } label: { Image(systemName: "square.and.pencil") }
                .accessibilityLabel("新建笔记")
            }
        }
        .navigationDestination(item: $editing) { NoteEditorView(note: $0) }
    }
}

struct CalculatorView: View {
    @State private var display = "0"
    @State private var stored: Double?
    @State private var pending: String?
    @State private var resetNext = false

    private let rows: [[String]] = [
        ["AC", "±", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["0", ".", "="],
    ]

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(display)
                .font(.system(size: 64, weight: .light).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 8)
                .accessibilityIdentifier("calculator.display")
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        Button { press(key) } label: {
                            Text(key)
                                .font(.system(size: 28, weight: .medium))
                                .frame(maxWidth: key == "0" ? .infinity : nil)
                                .frame(width: key == "0" ? nil : 74, height: 74)
                                .foregroundStyle(["÷", "×", "−", "+", "="].contains(key) ? .white : .primary)
                                .background(color(for: key), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("calculator.\(key)")
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cellBackground)
        .navigationTitle("计算器")
        .weChatNavigation()
    }

    private func color(for key: String) -> Color {
        if ["÷", "×", "−", "+", "="].contains(key) { return Color.brand }
        if ["AC", "±", "%"].contains(key) { return Color.dynamic(0xD4D4D2, 0x5A5A5A) }
        return Color.dynamic(0xF0F0F0, 0x333333)
    }

    private var value: Double { Double(display) ?? 0 }

    private func press(_ key: String) {
        switch key {
        case "0"..."9":
            if display == "0" || resetNext { display = key; resetNext = false } else { display += key }
        case ".":
            if resetNext { display = "0"; resetNext = false }
            if !display.contains(".") { display += "." }
        case "AC":
            display = "0"; stored = nil; pending = nil
        case "±":
            display = format(-value)
        case "%":
            display = format(value / 100)
        case "=":
            compute()
            pending = nil
        default:
            if pending != nil && !resetNext { compute() } else { stored = value }
            pending = key
            resetNext = true
        }
    }

    private func compute() {
        guard let stored, let pending else { return }
        let result: Double
        switch pending {
        case "+": result = stored + value
        case "−": result = stored - value
        case "×": result = stored * value
        case "÷": result = value == 0 ? .nan : stored / value
        default: return
        }
        display = result.isNaN ? "错误" : format(result)
        self.stored = result.isNaN ? nil : result
        resetNext = true
    }

    private func format(_ number: Double) -> String {
        if number == number.rounded() && abs(number) < 1e15 { return String(Int(number)) }
        return String(format: "%.10g", number)
    }
}
