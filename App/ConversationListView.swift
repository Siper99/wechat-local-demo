import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var context
    @Query private var conversations: [Conversation]
    @State private var path: [Conversation] = []
    @State private var editing: Conversation?
    @State private var showNewChat = false

    private var sorted: [Conversation] {
        conversations.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.lastActivity > b.lastActivity
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(sorted) { conversation in
                    ZStack {
                        // 隐藏 NavigationLink 自带的箭头
                        NavigationLink(value: conversation) { EmptyView() }.opacity(0)
                        ConversationRow(conversation: conversation)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(conversation.pinned ? Color.pinnedRow : Color(.systemBackground))
                    .swipeActions(edge: .trailing) {
                        Button("删除", role: .destructive) {
                            context.delete(conversation)
                            try? context.save()
                        }
                        Button(conversation.unread > 0 ? "标为已读" : "标为未读") {
                            conversation.unread = conversation.unread > 0 ? 0 : 1
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading) {
                        Button(conversation.pinned ? "取消置顶" : "置顶") { conversation.pinned.toggle() }
                            .tint(.gray)
                    }
                    .contextMenu {
                        Button("聊天信息", systemImage: "info.circle") { editing = conversation }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if conversations.isEmpty {
                    ContentUnavailableView("暂无聊天", systemImage: "bubble.left.and.bubble.right",
                                           description: Text("点右上角 ＋ 发起聊天"))
                }
            }
            .navigationTitle("WeChat")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Conversation.self) { ChatView(conversation: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewChat = true } label: { Image(systemName: "plus.circle") }
                }
            }
            .sheet(item: $editing) { ConversationSettingsView(conversation: $0) }
            .sheet(isPresented: $showNewChat) {
                NewChatView { path = [$0] }
            }
        }
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
