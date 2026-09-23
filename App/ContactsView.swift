import SwiftUI
import SwiftData

struct ContactsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Contact> { $0.isMe == false && $0.isSystem == false }) private var contacts: [Contact]
    @State private var showAdd = false
    @State private var search = ""
    @State private var feature: String?

    private var sections: [(letter: String, contacts: [Contact])] {
        Dictionary(grouping: contacts.filter { search.isEmpty || $0.name.localizedStandardContains(search) || $0.handle.localizedStandardContains(search) }) { PinyinIndex.letter(for: $0.name) }
            .map { entry in
                (letter: entry.key,
                 contacts: entry.value.sorted { PinyinIndex.latin($0.name) < PinyinIndex.latin($1.name) })
            }
            .sorted { a, b in
                if a.letter == "#" { return false }
                if b.letter == "#" { return true }
                return a.letter < b.letter
            }
    }

    private static let indexLetters = (65...90).map { String(UnicodeScalar($0)!) } + ["#"]

    /// 跳到该字母；没有该分组时跳到后面最近的分组
    private func jump(to letter: String, proxy: ScrollViewProxy) {
        let available = sections.map(\.letter)
        let order = Self.indexLetters
        guard let start = order.firstIndex(of: letter) else { return }
        if let target = order[start...].first(where: { available.contains($0) }) ?? available.last {
            proxy.scrollTo(target, anchor: .top)
        }
    }

    private func entry<Destination: View>(_ title: String, _ symbol: String, _ color: UInt32,
                                          @ViewBuilder destination: () -> Destination) -> some View {
        ZStack {
            NavigationLink { destination() } label: { EmptyView() }.opacity(0)
            ContactEntryRow(title: title, symbol: symbol, color: color)
        }
        .accessibilityIdentifier("contacts.entry.\(title)")
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                WeChatSearchBar(text: $search)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .id("top")
                if search.isEmpty {
                    entry("新的朋友", "person.fill.badge.plus", 0xFA9D3B) { NewFriendsView() }
                    entry("仅聊天的朋友", "person.bubble.fill", 0xFA9D3B) { ChatOnlyFriendsView() }
                    entry("群聊", "person.2.fill", 0x07C160) { GroupListView() }
                    entry("标签", "tag.fill", 0x1485EE) { TagsView() }
                    entry("公众号", "book.fill", 0x1485EE) { OfficialAccountsView(isService: false) }
                    entry("服务号", "rhombus.fill", 0x10AEFF) { OfficialAccountsView(isService: true) }
                    entry("企业微信联系人", "bubble.left.and.bubble.right", 0x2782D7) {
                        UnavailableFeatureView(title: "企业微信联系人", symbol: "building.2",
                                               message: "本地演示没有接入企业微信账号，暂无企业联系人。")
                    }
                }
                ForEach(sections, id: \.letter) { section in
                    Text(section.letter)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .frame(height: 44)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.cellBackground)
                        .listRowSeparator(.hidden)
                        .id(section.letter)
                        ForEach(section.contacts) { contact in
                            ZStack {
                                NavigationLink(value: contact) { EmptyView() }.opacity(0)
                                HStack(spacing: 12) {
                                    AvatarView(contact: contact, size: 40)
                                    Text(contact.name).font(.system(size: 17))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 56)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .swipeActions {
                                Button("删除", role: .destructive) {
                                    context.delete(contact)
                                    try? context.save()
                                }
                            }
                        }
                }
                Section {
                    Text("\(contacts.count) 个朋友")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("通讯录")
            .weChatNavigation()
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .trailing) {
                if search.isEmpty {
                    VStack(spacing: 0) {
                        Button { proxy.scrollTo("top", anchor: .top) } label: {
                            Image(systemName: "magnifyingglass").font(.system(size: 10, weight: .semibold))
                                .frame(width: 20, height: 16)
                        }
                        .accessibilityLabel("索引搜索")
                        ForEach(Self.indexLetters, id: \.self) { letter in
                            Button { jump(to: letter, proxy: proxy) } label: {
                                Text(letter).font(.system(size: 11, weight: .semibold))
                                    .frame(width: 20, height: 16)
                            }
                        }
                    }
                    .foregroundStyle(Color.dynamic(0x555555, 0xAAAAAA))
                    .padding(.trailing, 2)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "person.badge.plus") }
                }
            }
            .sheet(isPresented: $showAdd) { ContactEditView() }
            .alert(feature ?? "", isPresented: Binding(get: { feature != nil }, set: { if !$0 { feature = nil } })) {
                Button("知道了", role: .cancel) { }
            } message: { Text("当前版本支持一对一聊天，此功能暂未接入。") }
        }
    }
}

struct ContactDetailView: View {
    @Bindable var contact: Contact
    @Environment(\.modelContext) private var context
    @State private var openChat: Conversation?
    @State private var callRequest: CallRequest?
    @State private var showCallChoice = false
    @State private var showEdit = false
    @State private var showMore = false
    @State private var confirmDelete = false
    @State private var feature: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                header
                WeChatGroup {
                    NavigationLink { ContactRemarkView(contact: contact) } label: {
                        WeChatRow(title: "备注和标签", detail: contact.tags.joined(separator: "，"), plain: true)
                    }
                    .buttonStyle(.plain)
                    WeChatSeparator(leading: 16)
                    NavigationLink { FriendPermissionView(contact: contact) } label: {
                        WeChatRow(title: "朋友权限", detail: contact.chatOnly ? "仅聊天" : nil, plain: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("contact.permission")
                }
                WeChatGroup {
                    NavigationLink { MomentsView(authorID: contact.id, title: contact.name) } label: {
                        WeChatRow(title: "朋友圈", plain: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("contact.moments")
                    WeChatSeparator(leading: 16)
                    NavigationLink { moreInfo } label: { WeChatRow(title: "更多信息", plain: true) }
                        .buttonStyle(.plain)
                }
                WeChatGroup {
                    Button {
                        openChat = context.conversation(with: contact)
                    } label: {
                        actionLabel("发消息", "message")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("contact.sendMessage")
                    WeChatSeparator(leading: 0)
                    Button { showCallChoice = true } label: { actionLabel("音视频通话", "video") }
                        .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.chatBackground)
        .navigationTitle("")
        .weChatNavigation()
        .navigationDestination(item: $openChat) { ChatView(conversation: $0) }
        .confirmationDialog("", isPresented: $showCallChoice) {
            Button("视频通话") { callRequest = CallRequest(video: true) }
            Button("语音通话") { callRequest = CallRequest(video: false) }
        }
        .fullScreenCover(item: $callRequest) { request in
            CallView(peerName: contact.name, peerAvatar: contact.avatarData, video: request.video) { duration in
                let conversation = context.conversation(with: contact)
                let text = duration.map { "通话时长 " + LiveBroadcastView.format($0) } ?? "已取消"
                let message = context.addMessage(to: conversation, kind: .call, text: text, fromMe: true)
                message.isVideoCall = request.video
                try? context.save()
            }
        }
        .toolbar {
            // 新版微信：资料页右上角新增“编辑”按钮，直达备注
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showEdit = true } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("编辑")
                    .accessibilityIdentifier("contact.edit")
                Button { showMore = true } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("更多")
            }
        }
        .sheet(isPresented: $showEdit) { ContactEditView(contact: contact) }
        .confirmationDialog("", isPresented: $showMore) {
            Button("设置备注和标签") { showEdit = true }
            Button("删除联系人", role: .destructive) { confirmDelete = true }
        }
        .confirmationDialog("将联系人“\(contact.name)”删除，同时删除与该联系人的聊天记录", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除联系人", role: .destructive) {
                let contact = contact
                NotificationCenter.default.post(name: .popToRoot, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    context.delete(contact)
                    try? context.save()
                }
            }
        }
        .alert(feature ?? "", isPresented: Binding(get: { feature != nil }, set: { if !$0 { feature = nil } })) {
            Button("知道了", role: .cancel) { }
        } message: { Text("此入口暂未接入。") }
    }

    private var moreInfo: some View {
        List {
            LabeledContent("微信号", value: contact.handle)
            LabeledContent("标签", value: contact.tags.isEmpty ? "无" : contact.tags.joined(separator: "，"))
            LabeledContent("来源", value: "本地添加")
            LabeledContent("添加时间", value: ChatTime.chatLabel(contact.createdAt))
            LabeledContent("共同群聊", value: "\(contact.groups.count) 个")
        }
        .navigationTitle("更多信息")
        .weChatNavigation()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            AvatarView(contact: contact, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text(contact.name)
                    .font(.system(size: 22, weight: .semibold))
                    .lineLimit(1)
                Text("微信号：\(contact.handle)")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("地区：未设置")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .background(Color.cellBackground)
    }

    private func actionLabel(_ title: String, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 17))
            Text(title).font(.system(size: 17, weight: .medium))
        }
        .foregroundStyle(Color.linkBlue)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color.cellBackground)
        .contentShape(Rectangle())
    }
}

/// 通讯录顶部功能入口：40pt 彩色圆角图标 + 标题
struct ContactEntryRow: View {
    let title: String
    let symbol: String
    let color: UInt32

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color(UIColor(hex: color))))
            Text(title).font(.system(size: 17)).foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .frame(height: 56)
        .contentShape(Rectangle())
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] + 52 }
    }
}

struct IconRow: View {
    let icon: String
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color))
            Text(title).font(.system(size: 17))
        }
        .padding(.vertical, 2)
    }
}
