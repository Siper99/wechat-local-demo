import SwiftUI
import SwiftData

extension ModelContext {
    /// 新建群聊并写入一条系统提示
    @discardableResult
    func createGroup(with members: [Contact], name: String = "") -> Conversation {
        let conversation = Conversation()
        insert(conversation)
        conversation.isGroup = true
        conversation.groupName = name
        conversation.members = members
        let names = members.map(\.name).joined(separator: "、")
        addMessage(to: conversation, kind: .system, text: "你邀请\(names)加入了群聊", fromMe: true)
        try? save()
        return conversation
    }
}

// MARK: - 新的朋友

struct NewFriendsView: View {
    @Query(sort: \FriendRequest.createdAt, order: .reverse) private var requests: [FriendRequest]
    @Environment(\.modelContext) private var context
    @AppStorage("editMode") private var editMode = false
    @State private var showAdd = false
    @State private var showSimulate = false

    var body: some View {
        List {
            Section {
                Button { showAdd = true } label: {
                    Label("添加朋友", systemImage: "person.badge.plus").foregroundStyle(.primary)
                }
                .accessibilityIdentifier("newFriends.add")
                if editMode {
                    Button { showSimulate = true } label: { Label("模拟收到好友申请", systemImage: "wand.and.stars") }
                }
            }
            Section(requests.isEmpty ? "" : "近三天") {
                ForEach(requests) { request in
                    HStack(spacing: 12) {
                        AvatarView(name: request.name, data: nil, size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(request.name).font(.system(size: 16))
                            Text(request.greeting).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if request.accepted {
                            Text("已添加").font(.system(size: 14)).foregroundStyle(.secondary)
                        } else {
                            Button("接受") { accept(request) }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(height: 30)
                                .background(Color.brand, in: RoundedRectangle(cornerRadius: 4))
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("newFriends.accept.\(request.name)")
                        }
                    }
                    .swipeActions {
                        Button("删除", role: .destructive) {
                            context.delete(request)
                            try? context.save()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if requests.isEmpty { ContentUnavailableView("暂无好友申请", systemImage: "person.crop.circle.badge.plus") } }
        .navigationTitle("新的朋友")
        .weChatNavigation()
        .sheet(isPresented: $showAdd) { ContactEditView() }
        .sheet(isPresented: $showSimulate) { SimulateRequestSheet() }
    }

    private func accept(_ request: FriendRequest) {
        let contact = Contact(name: request.name)
        context.insert(contact)
        request.accepted = true
        let conversation = context.conversation(with: contact)
        context.addMessage(to: conversation, kind: .system, text: "你已添加了\(request.name)，现在可以开始聊天了。", fromMe: true)
        if !request.greeting.isEmpty {
            context.addMessage(to: conversation, text: request.greeting, fromMe: false, at: request.createdAt)
        }
        try? context.save()
    }
}

private struct SimulateRequestSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var greeting = "你好，我是"

    var body: some View {
        NavigationStack {
            Form {
                TextField("对方昵称", text: $name)
                TextField("验证消息", text: $greeting)
            }
            .navigationTitle("模拟好友申请")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        context.insert(FriendRequest(name: name.trimmingCharacters(in: .whitespaces), greeting: greeting))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 仅聊天的朋友

struct ChatOnlyFriendsView: View {
    @Query(filter: #Predicate<Contact> { $0.chatOnly == true && $0.isMe == false }, sort: \Contact.name)
    private var contacts: [Contact]

    var body: some View {
        List {
            ForEach(contacts) { contact in
                NavigationLink { ContactDetailView(contact: contact) } label: {
                    HStack(spacing: 12) { AvatarView(contact: contact, size: 40); Text(contact.name) }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if contacts.isEmpty {
                ContentUnavailableView("暂无仅聊天的朋友", systemImage: "person.bubble",
                                       description: Text("在好友资料页 → 朋友权限中设为\u{201C}仅聊天\u{201D}"))
            }
        }
        .navigationTitle("仅聊天的朋友")
        .weChatNavigation()
    }
}

// MARK: - 群聊

struct GroupListView: View {
    @Query(filter: #Predicate<Conversation> { $0.isGroup == true }) private var groups: [Conversation]
    @Environment(\.modelContext) private var context
    @State private var showCreate = false
    @State private var opened: Conversation?

    var body: some View {
        List {
            ForEach(groups.sorted { $0.title < $1.title }) { group in
                NavigationLink { ChatView(conversation: group) } label: {
                    HStack(spacing: 12) {
                        ConversationAvatar(conversation: group, size: 40)
                        Text(group.displayTitle)
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView {
                    Label("暂无群聊", systemImage: "person.3")
                } actions: {
                    Button("发起群聊") { showCreate = true }.buttonStyle(.borderedProminent).tint(Color.brand)
                }
            }
        }
        .navigationTitle("群聊")
        .weChatNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus.circle") }
                    .accessibilityLabel("发起群聊")
                    .accessibilityIdentifier("groups.create")
            }
        }
        .sheet(isPresented: $showCreate) {
            ContactMultiPicker(title: "发起群聊") { members in
                guard members.count >= 2 else { return }
                let group = context.createGroup(with: members)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { opened = group }
            }
        }
        .navigationDestination(item: $opened) { ChatView(conversation: $0) }
    }
}

// MARK: - 标签

struct TagsView: View {
    @Query(filter: #Predicate<Contact> { $0.isMe == false }) private var contacts: [Contact]
    @State private var showNew = false
    @State private var newTag = ""
    @State private var pickingFor: String?

    private var tags: [String] { Array(Set(contacts.flatMap(\.tags))).sorted() }

    var body: some View {
        List {
            ForEach(tags, id: \.self) { tag in
                NavigationLink { TagDetailView(tag: tag) } label: {
                    HStack {
                        Text(tag)
                        Text("(\(contacts.filter { $0.tags.contains(tag) }.count))").foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for tag in offsets.map({ tags[$0] }) {
                    contacts.forEach { $0.tags.removeAll { $0 == tag } }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if tags.isEmpty {
                ContentUnavailableView("暂无标签", systemImage: "tag", description: Text("点右上角新建标签并选择成员"))
            }
        }
        .navigationTitle("标签")
        .weChatNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { newTag = ""; showNew = true } label: { Image(systemName: "plus.circle") }
                    .accessibilityLabel("新建标签")
            }
        }
        .alert("新建标签", isPresented: $showNew) {
            TextField("标签名称", text: $newTag)
            Button("取消", role: .cancel) {}
            Button("选择成员") {
                let name = newTag.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { pickingFor = name }
            }
        }
        .sheet(item: Binding(get: { pickingFor.map(TagName.init) }, set: { pickingFor = $0?.name })) { tag in
            ContactMultiPicker(title: "添加成员") { members in
                members.forEach { if !$0.tags.contains(tag.name) { $0.tags.append(tag.name) } }
            }
        }
    }
}

private struct TagName: Identifiable {
    let name: String
    var id: String { name }
}

struct TagDetailView: View {
    let tag: String
    @Query(filter: #Predicate<Contact> { $0.isMe == false }, sort: \Contact.name) private var contacts: [Contact]
    @State private var showPicker = false

    private var members: [Contact] { contacts.filter { $0.tags.contains(tag) } }

    var body: some View {
        List {
            Section("成员（\(members.count)）") {
                ForEach(members) { contact in
                    NavigationLink { ContactDetailView(contact: contact) } label: {
                        HStack(spacing: 12) { AvatarView(contact: contact, size: 36); Text(contact.name) }
                    }
                    .swipeActions {
                        Button("移出", role: .destructive) { contact.tags.removeAll { $0 == tag } }
                    }
                }
                Button { showPicker = true } label: { Label("添加成员", systemImage: "plus") }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(tag)
        .weChatNavigation()
        .sheet(isPresented: $showPicker) {
            ContactMultiPicker(title: "添加成员", excluded: Set(members.map(\.id))) { picked in
                picked.forEach { if !$0.tags.contains(tag) { $0.tags.append(tag) } }
            }
        }
    }
}

// MARK: - 公众号 / 服务号

struct OfficialAccountsView: View {
    let isService: Bool
    @Query(sort: \OfficialAccount.name) private var accounts: [OfficialAccount]

    private var shown: [OfficialAccount] { accounts.filter { $0.isService == isService } }

    var body: some View {
        List {
            ForEach(shown) { account in
                NavigationLink { AccountDetailView(account: account) } label: {
                    HStack(spacing: 12) {
                        AccountIcon(account: account, size: 40)
                        Text(account.name)
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if shown.isEmpty { ContentUnavailableView(isService ? "暂无服务号" : "暂无公众号", systemImage: "book") }
        }
        .navigationTitle(isService ? "服务号" : "公众号")
        .weChatNavigation()
    }
}

struct AccountIcon: View {
    let account: OfficialAccount
    var size: CGFloat = 40
    var body: some View {
        Circle().fill(Color(hex: account.colorHex)).frame(width: size, height: size)
            .overlay(Image(systemName: account.symbol).font(.system(size: size * 0.45)).foregroundStyle(.white))
    }
}

struct AccountDetailView: View {
    let account: OfficialAccount

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    AccountIcon(account: account, size: 64)
                    Text(account.name).font(.system(size: 20, weight: .semibold))
                    Text(account.intro).font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section("文章") {
                ForEach(account.articles.sorted { $0.publishedAt > $1.publishedAt }) { article in
                    NavigationLink { ArticleView(article: article) } label: { ArticleRow(article: article) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("")
        .weChatNavigation()
    }
}

// MARK: - 好友资料：备注和标签、朋友权限

struct ContactRemarkView: View {
    @Bindable var contact: Contact
    @Query(filter: #Predicate<Contact> { $0.isMe == false }) private var contacts: [Contact]
    @State private var newTag = ""

    private var allTags: [String] { Array(Set(contacts.flatMap(\.tags))).sorted() }

    var body: some View {
        Form {
            Section("备注名") {
                TextField("备注名", text: $contact.name)
            }
            Section("标签") {
                ForEach(allTags, id: \.self) { tag in
                    Button {
                        if contact.tags.contains(tag) { contact.tags.removeAll { $0 == tag } } else { contact.tags.append(tag) }
                    } label: {
                        HStack {
                            Text(tag).foregroundStyle(.primary)
                            Spacer()
                            if contact.tags.contains(tag) { Image(systemName: "checkmark").foregroundStyle(Color.brand) }
                        }
                    }
                }
                HStack {
                    TextField("新建标签", text: $newTag)
                    Button("添加") {
                        let tag = newTag.trimmingCharacters(in: .whitespaces)
                        if !tag.isEmpty && !contact.tags.contains(tag) { contact.tags.append(tag) }
                        newTag = ""
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("设置备注和标签")
        .weChatNavigation()
    }
}

struct FriendPermissionView: View {
    @Bindable var contact: Contact

    var body: some View {
        Form {
            Section("设置朋友权限") {
                permissionRow("聊天、朋友圈、微信运动等", selected: !contact.chatOnly) { contact.chatOnly = false }
                permissionRow("仅聊天", selected: contact.chatOnly) { contact.chatOnly = true }
            }
            Section {
            } footer: {
                Text("设为仅聊天后，朋友圈中不再显示对方的动态。")
            }
        }
        .navigationTitle("朋友权限")
        .weChatNavigation()
    }

    private func permissionRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(Color.brand) }
            }
        }
    }
}
