import SwiftUI
import SwiftData

struct ConversationListView: View {
    var onOpen: (Conversation) -> Void
    @Environment(\.modelContext) private var context
    @Query private var conversations: [Conversation]
    @State private var editing: Conversation?
    @State private var showNewChat = false
    @State private var search = ""
    @State private var showAddContact = false
    @State private var featureNotice: String?
    @AppStorage("desktopLogin") private var desktopLogin = "Windows"
    @State private var swipedID: UUID?

    private var unreadTotal: Int {
        conversations.filter { !$0.muted }.reduce(0) { $0 + $1.unread }
    }

    private var sorted: [Conversation] {
        conversations.filter { conversation in
            search.isEmpty || conversation.title.localizedStandardContains(search) ||
            conversation.messages.contains { $0.text.localizedStandardContains(search) }
        }.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.lastActivity > b.lastActivity
        }
    }

    var body: some View {
        Group {
            ScrollView {
                LazyVStack(spacing: 0) {
                    WeChatSearchBar(text: $search)
                    if !desktopLogin.isEmpty && search.isEmpty { desktopLoginRow }
                    ForEach(sorted) { conversation in
                        SwipeActionRow(id: conversation.id, openID: $swipedID, actions: swipeActions(for: conversation)) {
                            ConversationRow(conversation: conversation)
                                .padding(.horizontal, 16)
                                .background(conversation.pinned ? Color.pinnedRow : Color(.systemBackground))
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 0.5).padding(.leading, 76)
                                }
                                // 用点按手势而非 Button：横向拖动后松手不会误打开聊天
                                .onTapGesture {
                                    if swipedID != nil { withAnimation(.snappy) { swipedID = nil } }
                                    else { onOpen(conversation) }
                                }
                                .accessibilityAddTraits(.isButton)
                        }
                        .accessibilityIdentifier("conversation.\(conversation.title)")
                        .contextMenu {
                            Button(conversation.pinned ? "取消置顶" : "置顶聊天", systemImage: "pin") { conversation.pinned.toggle() }
                            Button(conversation.unread > 0 ? "标为已读" : "标为未读", systemImage: "message.badge") {
                                conversation.unread = conversation.unread > 0 ? 0 : 1
                            }
                            Button("聊天信息", systemImage: "info.circle") { editing = conversation }
                            Button("删除该聊天", systemImage: "trash", role: .destructive) { delete(conversation) }
                        }
                    }
                }
                .background(Color(.systemBackground))
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                // 顶部下拉露出灰色，底部空白为白色
                VStack(spacing: 0) { Color.chatBackground; Color(.systemBackground) }
            }
            .overlay {
                if sorted.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "暂无聊天" : "无搜索结果", systemImage: "bubble.left.and.bubble.right",
                                           description: Text(search.isEmpty ? "点右上角 ＋ 发起聊天" : "试试其他联系人或聊天内容"))
                }
            }
            .navigationTitle(unreadTotal > 0 ? "微信 (\(unreadTotal))" : "微信")
            .weChatNavigation()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { featureNotice = "小程序" } label: {
                        HStack(spacing: 5) {
                            Circle().frame(width: 7, height: 7)
                            Circle().frame(width: 7, height: 7)
                        }
                        .foregroundStyle(Color.dynamic(0x3A3F4B, 0xD0D0D0))
                        .frame(width: 36, height: 30, alignment: .leading)
                    }
                    .accessibilityLabel("小程序")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("发起群聊", systemImage: "bubble.left.and.bubble.right") { showNewChat = true }
                        Button("添加朋友", systemImage: "person.badge.plus") { showAddContact = true }
                        Button("扫一扫", systemImage: "qrcode.viewfinder") { featureNotice = "扫一扫" }
                        Button("收付款", systemImage: "qrcode") { featureNotice = "收付款" }
                    } label: {
                        Image(systemName: "plus.circle").font(.system(size: 22, weight: .regular))
                    }
                    .accessibilityLabel("添加")
                }
            }
            .sheet(item: $editing) { ConversationSettingsView(conversation: $0) }
            .sheet(isPresented: $showNewChat) {
                NewChatView { onOpen($0) }
            }
            .sheet(isPresented: $showAddContact) { ContactEditView() }
            .alert(featureNotice ?? "", isPresented: Binding(get: { featureNotice != nil }, set: { if !$0 { featureNotice = nil } })) {
                Button("知道了", role: .cancel) { }
            } message: { Text("当前为本地聊天演示，此功能尚未接入。") }
        }
    }
}

extension ConversationListView {
    private var desktopLoginRow: some View {
        Button { featureNotice = "\(desktopLogin) 微信已登录" } label: {
            HStack(spacing: 0) {
                Image(systemName: desktopLogin == "Mac" ? "laptopcomputer" : "desktopcomputer")
                    .font(.system(size: 21, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(width: 48)
                Text("\(desktopLogin) 微信已登录")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.chatBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chats.desktopLogin")
    }

    /// 左滑：标为未读 / 删除（删除需再点一次“确认删除”）
    private func swipeActions(for conversation: Conversation) -> [SwipeAction] {
        [
            SwipeAction(title: conversation.unread > 0 ? "标为已读" : "标为未读", color: Color(UIColor(hex: 0x2782D7))) {
                conversation.unread = conversation.unread > 0 ? 0 : 1
            },
            SwipeAction(title: "删除", color: Color(UIColor(hex: 0xFA5151)), confirmTitle: "确认删除") {
                delete(conversation)
            },
        ]
    }

    private func delete(_ conversation: Conversation) {
        context.delete(conversation)
        try? context.save()
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(contact: conversation.peer, size: 48)
                .overlay(alignment: .topTrailing) { badge.offset(x: 6, y: -6) }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.title)
                        .font(.system(size: 17))
                        .lineLimit(1)
                    Spacer()
                    Text(ChatTime.listLabel(conversation.lastActivity))
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                HStack {
                    if !conversation.draft.isEmpty {
                        Text("[草稿]").foregroundStyle(.red).font(.system(size: 14))
                    }
                    Text(previewText)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.muted {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var previewText: String {
        if !conversation.draft.isEmpty { return conversation.draft }
        let preview = conversation.lastMessage?.preview ?? ""
        if conversation.muted && conversation.unread > 0 {
            return "[\(conversation.unread)条] " + preview
        }
        return preview
    }

    @ViewBuilder private var badge: some View {
        if conversation.unread > 0 {
            if conversation.muted {
                Circle().fill(.red).frame(width: 10, height: 10)
            } else {
                Text(conversation.unread > 99 ? "99+" : "\(conversation.unread)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Capsule().fill(.red))
            }
        }
    }
}

struct NewChatView: View {
    var onOpen: (Conversation) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Contact> { $0.isMe == false }, sort: \Contact.name) private var contacts: [Contact]
    @State private var showNewContact = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showNewContact = true } label: {
                        Label("新建联系人并发起聊天", systemImage: "person.badge.plus")
                    }
                }
                Section("选择联系人") {
                    ForEach(contacts) { contact in
                        Button { open(contact) } label: {
                            HStack(spacing: 12) {
                                AvatarView(contact: contact, size: 36)
                                Text(contact.name).foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("发起聊天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .sheet(isPresented: $showNewContact) {
                ContactEditView { contact in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { open(contact) }
                }
            }
        }
    }

    private func open(_ contact: Contact) {
        let conversation = context.conversation(with: contact)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onOpen(conversation) }
    }
}
