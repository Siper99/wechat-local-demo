import SwiftUI
import SwiftData
import PhotosUI
import AVKit

// MARK: - 服务

/// 与支付、金融相关的入口都能打开，但本地演示不提供收付款和余额（避免被误当作真实支付凭证）
struct ServicesView: View {
    private struct Service: Identifiable {
        let title: String
        let symbol: String
        let color: Int
        var id: String { title }
    }

    private let sections: [(String, [Service])] = [
        ("金融理财", [
            Service(title: "信用卡还款", symbol: "creditcard", color: 0x1485EE),
            Service(title: "借钱", symbol: "yensign.circle", color: 0xFA9D3B),
            Service(title: "理财", symbol: "chart.line.uptrend.xyaxis", color: 0xFFC300),
            Service(title: "保险服务", symbol: "shield", color: 0x07C160),
        ]),
        ("生活服务", [
            Service(title: "手机充值", symbol: "iphone", color: 0x1485EE),
            Service(title: "生活缴费", symbol: "bolt", color: 0x07C160),
            Service(title: "城市服务", symbol: "building.2", color: 0x1485EE),
            Service(title: "公益", symbol: "heart", color: 0xFA5151),
            Service(title: "医疗健康", symbol: "cross.case", color: 0x07C160),
            Service(title: "防骗中心", symbol: "exclamationmark.shield", color: 0xFA9D3B),
        ]),
        ("交通出行", [
            Service(title: "出行服务", symbol: "car", color: 0x07C160),
            Service(title: "火车票机票", symbol: "tram", color: 0x1485EE),
            Service(title: "打车", symbol: "car.side", color: 0xFA9D3B),
            Service(title: "酒店", symbol: "bed.double", color: 0x6467F0),
        ]),
        ("购物消费", [
            Service(title: "购物", symbol: "bag", color: 0xFA5151),
            Service(title: "外卖", symbol: "takeoutbag.and.cup.and.straw", color: 0xFFC300),
            Service(title: "电影演出", symbol: "film", color: 0xFA5151),
            Service(title: "团购", symbol: "ticket", color: 0xFA9D3B),
            Service(title: "二手", symbol: "arrow.2.squarepath", color: 0x07C160),
        ]),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    NavigationLink { UnavailableFeatureView(title: "收付款", symbol: "qrcode", message: "本地演示不提供收款码、付款码和转账。") } label: {
                        bigEntry("收付款", "qrcode.viewfinder")
                    }
                    NavigationLink { WalletView() } label: { bigEntry("钱包", "wallet.pass") }
                        .accessibilityIdentifier("services.wallet")
                }
                .buttonStyle(.plain)
                .padding(.vertical, 26)
                .background(Color(hex: 0x2AAE67), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 8)

                ForEach(sections.indices, id: \.self) { sectionIndex in
                    let section = sections[sectionIndex]
                    VStack(alignment: .leading, spacing: 0) {
                        Text(section.0).font(.system(size: 14)).foregroundStyle(.secondary)
                            .padding(.horizontal, 16).padding(.top, 14)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4), spacing: 0) {
                            ForEach(section.1) { service in
                                NavigationLink {
                                    UnavailableFeatureView(title: service.title, symbol: service.symbol)
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: service.symbol)
                                            .font(.system(size: 24))
                                            .foregroundStyle(Color(hex: service.color))
                                            .frame(height: 30)
                                        Text(service.title).font(.system(size: 13)).foregroundStyle(.primary)
                                            .lineLimit(1).minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 10)
        }
        .background(Color.chatBackground)
        .navigationTitle("服务")
        .weChatNavigation()
    }

    private func bigEntry(_ title: String, _ symbol: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 34, weight: .light))
            Text(title).font(.system(size: 16))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

struct WalletView: View {
    var body: some View {
        List {
            Section {
                row("零钱", "yensign.circle", 0xFA9D3B)
                row("零钱通", "chart.line.uptrend.xyaxis", 0xFFC300)
                row("银行卡", "creditcard", 0x1485EE)
                row("亲属卡", "person.2", 0xFA5151)
            } footer: {
                Text("本地演示不连接任何支付账户，不显示余额、不保存银行卡信息。")
            }
            Section {
                row("支付设置", "gearshape", 0x1485EE)
                row("消费者保护", "shield", 0x07C160)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("钱包")
        .weChatNavigation()
    }

    private func row(_ title: String, _ symbol: String, _ color: Int) -> some View {
        NavigationLink { UnavailableFeatureView(title: title, symbol: symbol, message: "本地演示不提供支付和资金功能。") } label: {
            Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(Color(hex: color)) }
        }
    }
}

// MARK: - 收藏（消息 + 笔记，分类筛选与搜索）

struct FavoritesView: View {
    @Query(filter: #Predicate<Message> { $0.isFavorite == true }, sort: \Message.sentAt, order: .reverse)
    private var favorites: [Message]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var context
    @State private var filter = "全部"
    @State private var search = ""
    @State private var editingNote: Note?
    @State private var viewerImage: ViewerImage?

    private let filters = ["全部", "笔记", "文字", "图片", "位置", "语音"]

    private enum Item: Identifiable {
        case message(Message), note(Note)
        var id: UUID {
            switch self {
            case .message(let m): return m.id
            case .note(let n): return n.id
            }
        }
        var date: Date {
            switch self {
            case .message(let m): return m.sentAt
            case .note(let n): return n.updatedAt
            }
        }
    }

    private var items: [Item] {
        let messageItems: [Item] = favorites.filter { message in
            switch filter {
            case "全部": return true
            case "文字": return message.kind == .text
            case "图片": return message.kind == .image
            case "位置": return message.kind == .location
            case "语音": return message.kind == .voice
            default: return false
            }
        }.map { .message($0) }
        let noteItems: [Item] = (filter == "全部" || filter == "笔记") ? notes.map { .note($0) } : []
        return (messageItems + noteItems)
            .filter { item in
                guard !search.isEmpty else { return true }
                switch item {
                case .message(let m): return m.preview.localizedStandardContains(search)
                case .note(let n): return n.text.localizedStandardContains(search)
                }
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            WeChatSearchBar(text: $search)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { name in
                        Button(name) { filter = name }
                            .font(.system(size: 14))
                            .foregroundStyle(filter == name ? Color.brand : Color.primary)
                            .padding(.horizontal, 14).frame(height: 30)
                            .background(Color(.systemBackground), in: Capsule())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .background(Color.chatBackground)
            List {
                ForEach(items) { item in
                    row(item)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("暂无收藏", systemImage: "cube",
                                           description: Text("长按聊天消息选择收藏，或点右上角 ＋ 新建笔记"))
                }
            }
        }
        .background(Color.chatBackground)
        .navigationTitle("收藏")
        .weChatNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { newNote() } label: { Image(systemName: "plus.circle") }
                    .accessibilityLabel("新建笔记")
                    .accessibilityIdentifier("favorites.newNote")
            }
        }
        .navigationDestination(item: $editingNote) { NoteEditorView(note: $0) }
        .fullScreenCover(item: $viewerImage) { ImageViewer(image: $0.image) }
    }

    @ViewBuilder private func row(_ item: Item) -> some View {
        switch item {
        case .message(let message):
            VStack(alignment: .leading, spacing: 10) {
                switch message.kind {
                case .image:
                    if let image = ImageCache.image(for: message.id, data: message.imageData) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 90, height: 90).clipped()
                            .onTapGesture { viewerImage = ViewerImage(image: image) }
                    }
                case .location:
                    Label(message.text, systemImage: "mappin.circle.fill").foregroundStyle(.primary)
                    if let address = message.locationAddress { Text(address).font(.system(size: 13)).foregroundStyle(.secondary) }
                case .voice:
                    Label("语音 \(Int(message.duration.rounded()))″", systemImage: "waveform")
                        .onTapGesture { VoicePlayer.shared.toggle(message) }
                default:
                    Text(message.text).font(.system(size: 16)).lineLimit(4)
                }
                Text("\(message.fromMe ? "我" : message.senderName ?? message.conversation?.title ?? "联系人")  \(ChatTime.chatLabel(message.sentAt))")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .swipeActions {
                Button("删除", role: .destructive) {
                    message.isFavorite = false
                    try? context.save()
                }
            }
        case .note(let note):
            VStack(alignment: .leading, spacing: 10) {
                Text(note.text.isEmpty ? "空笔记" : note.text).font(.system(size: 16)).lineLimit(4)
                    .foregroundStyle(note.text.isEmpty ? .secondary : .primary)
                HStack(spacing: 4) {
                    Image(systemName: "note.text").font(.system(size: 11))
                    Text("笔记  \(ChatTime.chatLabel(note.updatedAt))")
                }
                .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onTapGesture { editingNote = note }
            .swipeActions {
                Button("删除", role: .destructive) {
                    context.delete(note)
                    try? context.save()
                }
            }
        }
    }

    private func newNote() {
        let note = Note(text: "")
        context.insert(note)
        try? context.save()
        editingNote = note
    }
}

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $note.text)
            .font(.system(size: 17))
            .focused($focused)
            .padding(.horizontal, 12)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("笔记")
            .weChatNavigation()
            .accessibilityIdentifier("note.editor")
            .onAppear { if note.text.isEmpty { focused = true } }
            .onChange(of: note.text) { _, _ in note.updatedAt = .now }
            .onDisappear {
                if note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { context.delete(note) }
                try? context.save()
            }
    }
}

// MARK: - 作品（我发表的视频号视频）

struct WorksView: View {
    @Query(sort: \ChannelVideo.createdAt, order: .reverse) private var videos: [ChannelVideo]
    @State private var showImport = false
    @State private var playing: ChannelVideo?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                ForEach(videos) { video in
                    VideoThumbnail(video: video)
                        .aspectRatio(3 / 4, contentMode: .fill)
                        .clipped()
                        .overlay(alignment: .bottomLeading) {
                            Label(video.liked ? "1" : "0", systemImage: "heart")
                                .font(.system(size: 11)).foregroundStyle(.white).padding(6)
                        }
                        .onTapGesture { playing = video }
                }
            }
        }
        .overlay {
            if videos.isEmpty {
                ContentUnavailableView {
                    Label("还没有作品", systemImage: "square.on.square")
                } description: {
                    Text("从相册选择视频发表，发表后也会出现在视频号")
                } actions: {
                    Button("发表视频") { showImport = true }.buttonStyle(.borderedProminent).tint(Color.brand)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("作品")
        .weChatNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImport = true } label: { Image(systemName: "plus.circle") }.accessibilityLabel("发表视频")
            }
        }
        .sheet(isPresented: $showImport) { VideoImportSheet() }
        .fullScreenCover(item: $playing) { video in
            ChannelsPlayerView(videos: videos, startID: video.id)
        }
    }
}

// MARK: - 小店与卡包

struct ShopWalletView: View {
    @Query(sort: \WalletCard.createdAt, order: .reverse) private var cards: [WalletCard]
    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    private let kinds = ["会员卡", "优惠券", "票券"]

    var body: some View {
        List {
            Section("小店") {
                NavigationLink { UnavailableFeatureView(title: "订单", symbol: "shippingbox", message: "本地演示没有接入小店购物，暂无订单。") } label: {
                    Label("我的订单", systemImage: "shippingbox")
                }
                NavigationLink { UnavailableFeatureView(title: "购物车", symbol: "cart", message: "本地演示没有接入小店购物。") } label: {
                    Label("购物车", systemImage: "cart")
                }
            }
            ForEach(kinds, id: \.self) { kind in
                let items = cards.filter { $0.kindRaw == kind }
                Section(kind) {
                    if items.isEmpty {
                        Text("暂无\(kind)").foregroundStyle(.secondary)
                    }
                    ForEach(items) { card in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6).fill(Color(hex: card.colorHex))
                                .frame(width: 44, height: 30)
                                .overlay(Image(systemName: kind == "会员卡" ? "creditcard" : "ticket").foregroundStyle(.white))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.title)
                                if !card.note.isEmpty { Text(card.note).font(.system(size: 13)).foregroundStyle(.secondary) }
                            }
                        }
                        .swipeActions {
                            Button("删除", role: .destructive) {
                                context.delete(card)
                                try? context.save()
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("小店与卡包")
        .weChatNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus.circle") }
                    .accessibilityLabel("添加卡券")
                    .accessibilityIdentifier("wallet.add")
            }
        }
        .sheet(isPresented: $showAdd) { AddCardSheet(kinds: kinds) }
    }
}

private struct AddCardSheet: View {
    let kinds: [String]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "会员卡"
    @State private var title = ""
    @State private var note = ""
    @State private var color = 0x07C160

    private let colors = [0x07C160, 0x1485EE, 0xFA9D3B, 0xFA5151, 0x6467F0, 0x333333]

    var body: some View {
        NavigationStack {
            Form {
                Picker("类型", selection: $kind) { ForEach(kinds, id: \.self) { Text($0) } }
                    .pickerStyle(.segmented)
                TextField("名称，如：咖啡店会员卡", text: $title).accessibilityIdentifier("wallet.title")
                TextField("备注，如：满 50 减 10、有效期", text: $note)
                HStack {
                    ForEach(colors, id: \.self) { value in
                        Circle().fill(Color(hex: value)).frame(width: 28, height: 28)
                            .overlay(Circle().stroke(.primary, lineWidth: color == value ? 2 : 0).padding(-3))
                            .onTapGesture { color = value }
                            .frame(maxWidth: .infinity)
                    }
                }
                Section {
                } footer: {
                    Text("只保存名称和备注，请勿填写卡号、密码等敏感信息。")
                }
            }
            .navigationTitle("添加卡券")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        context.insert(WalletCard(kind: kind, title: title.trimmingCharacters(in: .whitespaces),
                                                  note: note.trimmingCharacters(in: .whitespaces), colorHex: color))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("wallet.save")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 表情

struct StickersView: View {
    @Query(sort: \Sticker.createdAt, order: .reverse) private var stickers: [Sticker]
    @Environment(\.modelContext) private var context
    @State private var items: [PhotosPickerItem] = []
    @State private var editing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("添加的表情会出现在聊天的表情面板（♡ 标签）").font(.system(size: 13)).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.top, 12)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    PhotosPicker(selection: $items, maxSelectionCount: 9, matching: .images) {
                        RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(Image(systemName: "plus").font(.system(size: 26, weight: .light)).foregroundStyle(.secondary))
                    }
                    .accessibilityLabel("添加表情")
                    ForEach(stickers) { sticker in
                        StickerImage(sticker: sticker)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(alignment: .topTrailing) {
                                if editing {
                                    Button {
                                        context.delete(sticker)
                                        try? context.save()
                                    } label: {
                                        Image(systemName: "minus.circle.fill").symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .red).font(.system(size: 20))
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("我的表情")
        .weChatNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editing ? "完成" : "整理") { editing.toggle() }.disabled(stickers.isEmpty && !editing)
            }
        }
        .onChange(of: items) { _, picked in
            guard !picked.isEmpty else { return }
            Task {
                for item in picked {
                    if let raw = try? await item.loadTransferable(type: Data.self),
                       let data = ImageUtil.downsampledJPEG(raw, maxPixel: 400) {
                        context.insert(Sticker(data: data))
                    }
                }
                try? context.save()
                items = []
            }
        }
    }
}

struct StickerImage: View {
    let sticker: Sticker
    var body: some View {
        if let image = ImageCache.image(for: sticker.id, data: sticker.data) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15))
        }
    }
}

// MARK: - 我的二维码

struct MyQRCodeView: View {
    @Query(filter: #Predicate<Contact> { $0.isMe == true }) private var meList: [Contact]
    private var me: Contact? { meList.first }

    var body: some View {
        VStack {
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    AvatarView(contact: me, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(me?.name ?? "我").font(.system(size: 18, weight: .semibold))
                        Text("本地演示").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                if let image = QRCode.image(for: "wechat-local-demo://user/\(me?.handle ?? "wxid_me")") {
                    Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                        .frame(width: 240, height: 240)
                        .overlay { AvatarView(contact: me, size: 40).padding(3).background(.white, in: RoundedRectangle(cornerRadius: 6)) }
                }
                Text("扫一扫上面的二维码图案，加我为朋友").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(24)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .padding(24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.chatBackground)
        .navigationTitle("我的二维码")
        .weChatNavigation()
    }
}
