import SwiftUI
import SwiftData
import SafariServices
import CoreImage.CIFilterBuiltins

extension Color {
    init(hex: Int) { self.init(UIColor(hex: UInt32(hex))) }
}

enum UITesting {
    static let enabled = ProcessInfo.processInfo.arguments.contains("-ui-testing")
}

extension View {
    /// UI 测试时使用英文键盘，避免拼音输入法吞掉 typeText 的英文
    func testingKeyboard() -> some View {
        keyboardType(UITesting.enabled ? .asciiCapable : .default)
    }
}

// MARK: - 群聊九宫格头像

struct GroupAvatarView: View {
    let members: [Contact]
    var size: CGFloat = 48

    private var shown: [Contact] { Array(members.prefix(9)) }
    private var columns: Int { shown.count <= 1 ? 1 : (shown.count <= 4 ? 2 : 3) }
    private var gap: CGFloat { max(1.5, size * 0.03) }
    private var cell: CGFloat { (size - gap * CGFloat(columns + 1)) / CGFloat(columns) }

    /// 按行拆分，最后一行不满时居中（与微信一致）
    private var rows: [[Contact]] {
        let items = shown
        let firstRowCount = items.count % columns == 0 ? columns : items.count % columns
        var result: [[Contact]] = [Array(items.prefix(firstRowCount))]
        var index = firstRowCount
        while index < items.count {
            result.append(Array(items[index..<min(index + columns, items.count)]))
            index += columns
        }
        return result
    }

    var body: some View {
        ZStack {
            Color.dynamic(0xDDDDDD, 0x3A3A3A)
            VStack(spacing: gap) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(rows[row]) { contact in
                            AvatarView(contact: contact, size: cell)
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
    }
}

/// 会话头像：单聊显示对方头像，群聊显示九宫格
struct ConversationAvatar: View {
    let conversation: Conversation
    var size: CGFloat = 48
    @Query(filter: #Predicate<Contact> { $0.isMe == true }) private var meList: [Contact]

    var body: some View {
        if conversation.isGroup {
            GroupAvatarView(members: conversation.members.sorted { $0.createdAt < $1.createdAt } + meList.prefix(1), size: size)
        } else {
            AvatarView(contact: conversation.peer, size: size)
        }
    }
}

// MARK: - 二维码

enum QRCode {
    static func image(for text: String, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// 识别图片中的二维码
    static func decode(_ image: UIImage) -> String? {
        guard let ci = CIImage(image: image),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else { return nil }
        return detector.features(in: ci).compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first
    }
}

// MARK: - 应用内浏览器

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(hex: 0x07C160)
        return controller
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

extension URL {
    /// 用户输入的网址补全 https://
    static func userInput(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let full = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: full), url.host() != nil else { return nil }
        return url
    }

    static func webSearch(_ query: String) -> URL? {
        var components = URLComponents(string: "https://www.bing.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}

// MARK: - 暂不支持的入口（仍可打开，说明原因）

struct UnavailableFeatureView: View {
    let title: String
    var symbol: String = "network.slash"
    var message: String = "该服务需要联网账号或支付能力，本地演示未接入。"

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.chatBackground)
        .navigationTitle(title)
        .weChatNavigation()
    }
}

// MARK: - 联系人多选（建群、标签）

struct ContactMultiPicker: View {
    let title: String
    var excluded: Set<UUID> = []
    var initial: Set<UUID> = []
    var confirmTitle = "完成"
    var onDone: ([Contact]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Contact> { $0.isMe == false && $0.isSystem == false }, sort: \Contact.name)
    private var contacts: [Contact]
    @State private var selected: Set<UUID> = []
    @State private var search = ""

    private var visible: [Contact] {
        contacts.filter { !excluded.contains($0.id) && (search.isEmpty || $0.name.localizedStandardContains(search)) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visible) { contact in
                    Button {
                        if selected.contains(contact.id) { selected.remove(contact.id) } else { selected.insert(contact.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selected.contains(contact.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(selected.contains(contact.id) ? Color.brand : Color.secondary.opacity(0.5))
                            AvatarView(contact: contact, size: 40)
                            Text(contact.name).foregroundStyle(.primary)
                        }
                    }
                    .accessibilityIdentifier("pick.\(contact.name)")
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索")
            .overlay {
                if contacts.isEmpty { ContentUnavailableView("暂无联系人", systemImage: "person.2") }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? confirmTitle : "\(confirmTitle)(\(selected.count))") {
                        onDone(contacts.filter { selected.contains($0.id) })
                        dismiss()
                    }
                    .disabled(selected.isEmpty && initial.isEmpty)
                    .accessibilityIdentifier("pick.done")
                }
            }
            .onAppear { selected = initial }
        }
    }
}

// MARK: - 新版图标（按实机截图绘制）

enum WeChatIcon {
    /// 有自绘图标的入口
    static let custom: Set<String> = ["看一看", "游戏", "附近的人", "收藏", "视频号", "直播"]

    @ViewBuilder
    static func view(_ title: String) -> some View {
        switch title {
        case "看一看":
            ZStack {
                Triangle().stroke(Color(hex: 0xF6C543), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                Triangle().rotation(.degrees(180))
                    .stroke(Color(hex: 0xF6C543), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
            .frame(width: 22, height: 22)
        case "游戏":
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(AngularGradient(colors: [Color(hex: 0xFA5151), Color(hex: 0xFFC300), Color(hex: 0x07C160),
                                                     Color(hex: 0x1485EE), Color(hex: 0xFA5151)], center: .center),
                            lineWidth: 2.2)
                    .frame(width: 17, height: 17)
                    .rotationEffect(.degrees(45))
                Circle().stroke(Color(hex: 0x1485EE), lineWidth: 1.8).frame(width: 7, height: 7)
            }
            .frame(width: 24, height: 24)
        case "附近的人":
            Image(systemName: "person.wave.2")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Color(hex: 0x1485EE))
        case "收藏":
            Image(systemName: "cube")
                .font(.system(size: 21, weight: .light))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFC300), Color(hex: 0xFA5151), Color(hex: 0x1485EE)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case "视频号":
            Image(systemName: "infinity")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Color(hex: 0xFA9D3B))
        case "直播":
            Image(systemName: "circle.circle")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color(hex: 0xFA5151))
        default:
            EmptyView()
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.03, y: rect.maxY - rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.03, y: rect.maxY - rect.height * 0.22))
        path.closeSubpath()
        return path
    }
}

// MARK: - 通用小组件

/// 大号圆角入口按钮（服务页、面板等）
struct TileButton: View {
    let title: String
    let symbol: String
    var color: Color = .brand
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                    .frame(height: 30)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 按天/分钟显示朋友圈、文章时间
enum RelativeTime {
    static func label(_ date: Date, now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60))分钟前" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))小时前" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        let days = Int(seconds / 86_400)
        if days < 30 { return "\(days)天前" }
        return ChatTime.listLabel(date, now: now)
    }
}
