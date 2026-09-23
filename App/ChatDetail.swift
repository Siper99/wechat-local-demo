import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 聊天详情（聊天页右上角 ···）

struct ConversationSettingsView: View {
    @Bindable var conversation: Conversation
    /// 查找聊天内容里点中某条消息：回到聊天页并定位
    var onJump: ((UUID) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @AppStorage("editMode") private var editMode = false
    @State private var confirmClear = false
    @State private var showProfile = false
    @State private var showAddMembers = false
    @State private var confirmLeave = false
    @State private var showBackground = false
    @State private var newGroup: Conversation?
    @State private var openedContact: Contact?
    @State private var toast: String?

    private var people: [Contact] {
        conversation.isGroup ? conversation.members.sorted { $0.createdAt < $1.createdAt } : [conversation.peer].compactMap { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                members
                if conversation.isGroup {
                    WeChatGroup {
                        HStack {
                            Text("群聊名称").font(.system(size: 17))
                            TextField("未命名", text: $conversation.groupName)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Color.wcSecondary)
                                .accessibilityIdentifier("chatInfo.groupName")
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                    }
                }
                WeChatGroup {
                    NavigationLink { ChatSearchView(conversation: conversation, onJump: onJump) } label: {
                        InfoRow(title: "查找聊天内容")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chatInfo.search")
                }
                WeChatGroup {
                    ToggleRow(title: "消息免打扰", isOn: $conversation.muted, id: "chatInfo.mute")
                    WeChatSeparator(leading: 16)
                    ToggleRow(title: "置顶聊天", isOn: $conversation.pinned, id: "chatInfo.pin")
                    WeChatSeparator(leading: 16)
                    ToggleRow(title: "提醒", isOn: $conversation.remind, id: "chatInfo.remind")
                }
                WeChatGroup {
                    Button { showBackground = true } label: { InfoRow(title: "设置当前聊天背景") }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("chatInfo.background")
                }
                if editMode {
                    WeChatGroup {
                        if conversation.peer != nil {
                            Button { showProfile = true } label: { InfoRow(title: "修改头像和资料") }
                                .buttonStyle(.plain)
                            WeChatSeparator(leading: 16)
                        }
                        Stepper("未读数：\(conversation.unread)", value: $conversation.unread, in: 0...999)
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                    }
                }
                WeChatGroup {
                    Button { confirmClear = true } label: { InfoRow(title: "清空聊天记录", chevron: false) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("chatInfo.clear")
                }
                WeChatGroup {
                    NavigationLink { ComplaintView(target: conversation.title) } label: { InfoRow(title: "投诉") }
                        .buttonStyle(.plain)
                }
                if conversation.isGroup {
                    WeChatGroup {
                        Button { confirmLeave = true } label: {
                            Text("退出群聊").font(.system(size: 17)).foregroundStyle(Color(hex: 0xFA5151))
                                .frame(maxWidth: .infinity).frame(height: 56).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.chatBackground)
        .navigationTitle(conversation.isGroup ? "聊天信息(\(conversation.members.count + 1))" : "聊天详情")
        .weChatNavigation()
        .navigationDestination(item: $openedContact) { ContactDetailView(contact: $0) }
        .navigationDestination(item: $newGroup) { ChatView(conversation: $0) }
        .sheet(isPresented: $showProfile) {
            if let peer = conversation.peer { ContactEditView(contact: peer) }
        }
        .sheet(isPresented: $showBackground) {
            ChatBackgroundSheet(conversation: conversation) { showToast("已设置") }
        }
        .sheet(isPresented: $showAddMembers) {
            ContactMultiPicker(title: conversation.isGroup ? "添加群成员" : "发起群聊",
                               excluded: Set(people.map(\.id))) { picked in
                guard !picked.isEmpty else { return }
                if conversation.isGroup {
                    conversation.members.append(contentsOf: picked)
                    context.addMessage(to: conversation, kind: .system,
                                       text: "你邀请\(picked.map(\.name).joined(separator: "、"))加入了群聊", fromMe: true)
                    try? context.save()
                } else {
                    let group = context.createGroup(with: people + picked)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { newGroup = group }
                }
            }
        }
        .confirmationDialog("退出后不会再收到此群聊消息", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("退出", role: .destructive) {
                let conversation = conversation
                NotificationCenter.default.post(name: .popToRoot, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    context.delete(conversation)
                    try? context.save()
                }
            }
        }
        .confirmationDialog("确定删除和\(conversation.title)的聊天记录吗？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清空聊天记录", role: .destructive) {
                conversation.messages.forEach { context.delete($0) }
                try? context.save()
                showToast("已清空")
            }
        }
        .overlay {
            if let toast {
                Text(toast).font(.system(size: 15)).foregroundStyle(.white)
                    .padding(20).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
            }
        }
    }

    /// 成员头像：50pt，列宽 66pt；最后是虚线“＋”
    private var members: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(66), spacing: 0), count: 5), alignment: .leading, spacing: 12) {
            ForEach(people) { person in
                Button { openedContact = person } label: {
                    VStack(spacing: 6) {
                        AvatarView(contact: person, size: 50)
                        Text(person.name).font(.system(size: 13)).foregroundStyle(Color.wcSecondary).lineLimit(1)
                    }
                    .frame(width: 60)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chatInfo.member.\(person.name)")
            }
            Button { showAddMembers = true } label: {
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.wcTips, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "plus").font(.system(size: 24, weight: .light)).foregroundStyle(Color.wcTips))
                    Text(" ").font(.system(size: 13))
                }
                .frame(width: 60)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(conversation.isGroup ? "添加群成员" : "发起群聊")
            .accessibilityIdentifier("chatInfo.addMember")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cellBackground)
    }

    private func showToast(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast = nil }
    }
}

/// 设置当前聊天背景：从相册选图或恢复默认
struct ChatBackgroundSheet: View {
    @Bindable var conversation: Conversation
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            List {
                PhotosPicker(selection: $item, matching: .images) {
                    Text("从手机相册选择").foregroundStyle(.primary)
                }
                if conversation.backgroundData != nil {
                    Button("恢复默认背景") {
                        conversation.backgroundData = nil
                        onDone()
                        dismiss()
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("设置当前聊天背景")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .onChange(of: item) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let raw = try? await newItem.loadTransferable(type: Data.self) {
                        conversation.backgroundData = ImageUtil.downsampledJPEG(raw, maxPixel: 1600)
                        onDone()
                    }
                    dismiss()
                }
            }
        }
        .presentationDetents([.height(220)])
    }
}

// MARK: - 查找聊天内容

enum ChatSearchCategory: String, CaseIterable, Identifiable {
    case date = "日期", media = "图片与视频", file = "文件", link = "链接", audio = "音乐与音频", trade = "交易",
         miniProgram = "小程序", channels = "视频号", card = "名片", location = "位置", note = "笔记",
         shop = "商品与小店", gift = "礼物", sticker = "表情"
    var id: String { rawValue }
}

struct ChatSearchView: View {
    let conversation: Conversation
    var onJump: ((UUID) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var category: ChatSearchCategory?
    @FocusState private var focused: Bool

    private var results: [Message] {
        let keyword = text.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return [] }
        return conversation.sortedMessages.reversed().filter {
            $0.kind != .system && ($0.text.localizedStandardContains(keyword)
                || ($0.locationAddress ?? "").localizedStandardContains(keyword))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.wcTips)
                    TextField("搜索", text: $text)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("chatSearch.field")
                        .testingKeyboard()
                    if !text.isEmpty {
                        Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.wcTips) }
                            .accessibilityLabel("清除")
                    }
                }
                .font(.system(size: 17))
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(Color.cellBackground, in: RoundedRectangle(cornerRadius: 8))
                Button("取消") { dismiss() }
                    .font(.system(size: 17))
                    .foregroundStyle(Color.linkBlue)
                    .accessibilityIdentifier("chatSearch.cancel")
            }
            .padding(.leading, 8)
            .padding(.trailing, 16)
            .padding(.vertical, 8)

            if text.trimmingCharacters(in: .whitespaces).isEmpty {
                categories
            } else if results.isEmpty {
                Text("无相关聊天记录").font(.system(size: 15)).foregroundStyle(Color.wcTips)
                    .padding(.top, 60)
                Spacer()
            } else {
                MessageResultList(conversation: conversation, messages: results, keyword: text, onJump: jump)
            }
        }
        .background(Color.chatBackground)
        .toolbar(.hidden, for: .navigationBar)
        .edgeSwipeBack()
        .onAppear { focused = true }
        .navigationDestination(item: $category) { category in
            ChatCategoryView(conversation: conversation, category: category, onJump: jump)
        }
    }

    private var categories: some View {
        VStack(spacing: 0) {
            Text("快速搜索聊天内容").font(.system(size: 15)).foregroundStyle(Color.wcTips)
                .padding(.top, 44).padding(.bottom, 28)
            let all = ChatSearchCategory.allCases
            ForEach(Array(stride(from: 0, to: all.count, by: 3)), id: \.self) { start in
                HStack(spacing: 0) {
                    ForEach(start..<min(start + 3, all.count), id: \.self) { index in
                        Button { category = all[index] } label: {
                            Text(all[index].rawValue).font(.system(size: 17)).foregroundStyle(Color.linkBlue)
                                .frame(width: 100, height: 49)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("chatSearch.\(all[index].rawValue)")
                        .overlay(alignment: .trailing) {
                            if index % 3 != 2 && index < all.count - 1 {
                                Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 0.5, height: 20)
                            }
                        }
                    }
                }
                .frame(width: 300, alignment: .leading)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func jump(_ id: UUID) {
        onJump?(id)
    }
}

/// 搜索结果：头像、发送者、时间、命中文字
struct MessageResultList: View {
    let conversation: Conversation
    let messages: [Message]
    var keyword = ""
    var onJump: (UUID) -> Void
    @Query(filter: #Predicate<Contact> { $0.isMe == true }) private var meList: [Contact]

    var body: some View {
        List(messages) { message in
            Button { onJump(message.id) } label: {
                HStack(alignment: .top, spacing: 12) {
                    AvatarView(contact: sender(message), size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(sender(message)?.name ?? message.senderName ?? conversation.title)
                                .font(.system(size: 15)).foregroundStyle(Color.wcSecondary).lineLimit(1)
                            Spacer()
                            Text(ChatTime.listLabel(message.sentAt)).font(.system(size: 12)).foregroundStyle(Color.wcTips)
                        }
                        highlighted(message.preview).font(.system(size: 16)).lineLimit(2)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("chatSearch.result")
        }
        .listStyle(.plain)
    }

    private func sender(_ message: Message) -> Contact? {
        if message.fromMe { return meList.first }
        guard conversation.isGroup else { return conversation.peer }
        return conversation.members.first { $0.id == message.senderID }
    }

    /// 命中的关键字标绿
    private func highlighted(_ text: String) -> Text {
        let keyword = keyword.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty, let range = text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return Text(text)
        }
        var attributed = AttributedString(text)
        if let lower = AttributedString.Index(range.lowerBound, within: attributed),
           let upper = AttributedString.Index(range.upperBound, within: attributed) {
            attributed[lower..<upper].foregroundColor = Color.brand
        }
        return Text(attributed)
    }
}

/// 按类型查找：日期、图片与视频、位置、名片、音乐与音频、链接等
struct ChatCategoryView: View {
    let conversation: Conversation
    let category: ChatSearchCategory
    var onJump: (UUID) -> Void
    @State private var day = Date()
    @State private var viewer: ViewerImage?

    private var messages: [Message] {
        let all = conversation.sortedMessages.reversed().filter { $0.kind != .system }
        switch category {
        case .date: return all.filter { Calendar.current.isDate($0.sentAt, inSameDayAs: day) }
        case .media: return all.filter { $0.kind == .image }
        case .audio: return all.filter { $0.kind == .voice }
        case .card: return all.filter { $0.kind == .card }
        case .location: return all.filter { $0.kind == .location }
        case .link: return all.filter { $0.kind == .text && ($0.text.contains("http://") || $0.text.contains("https://")) }
        default: return []
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if category == .date {
                DatePicker("日期", selection: $day, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .tint(Color.brand)
                    .padding(.horizontal, 12)
                    .background(Color.cellBackground)
            }
            if category == .media && !messages.isEmpty {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4), spacing: 2) {
                        ForEach(messages) { message in
                            if let data = message.imageData, let image = UIImage(data: data) {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(minWidth: 0, maxWidth: .infinity).aspectRatio(1, contentMode: .fit).clipped()
                                    .onTapGesture { viewer = ViewerImage(image: image) }
                                    .contextMenu { Button("定位到聊天位置") { onJump(message.id) } }
                            }
                        }
                    }
                }
            } else if messages.isEmpty {
                Text(category == .date ? "这一天没有聊天记录" : "暂无\(category.rawValue)")
                    .font(.system(size: 15)).foregroundStyle(Color.wcTips)
                    .padding(.top, 60)
                Spacer()
            } else {
                MessageResultList(conversation: conversation, messages: messages, onJump: onJump)
            }
        }
        .background(Color.chatBackground)
        .navigationTitle(category.rawValue)
        .weChatNavigation()
        .toolbar(.visible, for: .navigationBar)
        .fullScreenCover(item: $viewer) { ImageViewer(image: $0.image) }
    }
}
