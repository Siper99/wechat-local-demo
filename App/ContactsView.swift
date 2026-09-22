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

    private func entry(_ title: String, _ symbol: String, _ color: UInt32) -> some View {
        Button { feature = title } label: { ContactEntryRow(title: title, symbol: symbol, color: color) }
            .buttonStyle(.plain)
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
                    Button { showAdd = true } label: { ContactEntryRow(title: "新的朋友", symbol: "person.fill.badge.plus", color: 0xFA9D3B) }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    entry("仅聊天的朋友", "person.bubble.fill", 0xFA9D3B)
                    entry("群聊", "person.2.fill", 0x07C160)
                    entry("标签", "tag.fill", 0x1485EE)
                    entry("公众号", "book.fill", 0x1485EE)
                    entry("服务号", "rhombus.fill", 0x10AEFF)
                    entry("企业微信联系人", "bubble.left.and.bubble.right", 0x2782D7)
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
                        .listRowBackground(Color(.systemBackground))
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
    @Environment(\.dismiss) private var dismiss
    @State private var openChat: Conversation?
    @State private var showEdit = false
    @State private var showMore = false
    @State private var confirmDelete = false
    @State private var feature: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                header
                WeChatGroup {
                    Button { showEdit = true } label: { WeChatRow(title: "备注和标签", plain: true) }
                        .buttonStyle(.plain)
                    WeChatSeparator(leading: 16)
                    Button { feature = "朋友权限" } label: { WeChatRow(title: "朋友权限", plain: true) }
                        .buttonStyle(.plain)
                }
                WeChatGroup {
                    Button { feature = "朋友圈" } label: { WeChatRow(title: "朋友圈", plain: true) }
                        .buttonStyle(.plain)
                    WeChatSeparator(leading: 16)
                    Button { feature = "更多信息" } label: { WeChatRow(title: "更多信息", plain: true) }
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
                    Button { feature = "音视频通话" } label: { actionLabel("音视频通话", "video") }
                        .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.chatBackground)
        .navigationTitle("")
        .weChatNavigation()
        .navigationDestination(item: $openChat) { ChatView(conversation: $0) }
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
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    context.delete(contact)
                    try? context.save()
                }
            }
        }
        .alert(feature ?? "", isPresented: Binding(get: { feature != nil }, set: { if !$0 { feature = nil } })) {
            Button("知道了", role: .cancel) { }
        } message: { Text("此入口暂未接入。") }
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
        .background(Color(.systemBackground))
    }

    private func actionLabel(_ title: String, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 17))
            Text(title).font(.system(size: 17, weight: .medium))
        }
        .foregroundStyle(Color.linkBlue)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color(.systemBackground))
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
