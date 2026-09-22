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
    @State private var openChat: Conversation?
    @State private var showEdit = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    AvatarView(contact: contact, size: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(contact.name).font(.system(size: 22, weight: .semibold))
                        Text("微信号：\(contact.handle)")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            Section {
                IconRow(icon: "photo.on.rectangle", color: .blue, title: "朋友圈")
                IconRow(icon: "info.circle.fill", color: .gray, title: "更多信息")
            }
            Section {
                Button {
                    openChat = context.conversation(with: contact)
                } label: {
                    Label("发消息", systemImage: "message")
                        .font(.system(size: 17, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $openChat) { ChatView(conversation: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("编辑") { showEdit = true } }
        }
        .sheet(isPresented: $showEdit) { ContactEditView(contact: contact) }
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
