import SwiftUI
import SwiftData

/// 通讯录顶部入口，统一在根 NavigationStack 上声明目的页
enum ContactRoute: Hashable {
    case newFriends, chatOnly, groups, tags, officialAccounts, serviceAccounts, wecom

    @ViewBuilder var destination: some View {
        switch self {
        case .newFriends: NewFriendsView()
        case .chatOnly: ChatOnlyFriendsView()
        case .groups: GroupListView()
        case .tags: TagsView()
        case .officialAccounts: OfficialAccountsView(isService: false)
        case .serviceAccounts: OfficialAccountsView(isService: true)
        case .wecom:
            UnavailableFeatureView(title: "企业微信联系人", symbol: "building.2",
                                   message: "本地演示没有接入企业微信账号，暂无企业联系人。")
        }
    }
}

struct ContactsView: View {
    var open: (ContactRoute) -> Void = { _ in }
    var openContact: (Contact) -> Void = { _ in }
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

    private func entry(_ title: String, _ asset: String, _ route: ContactRoute) -> some View {
        Button { open(route) } label: { ContactEntryRow(title: title, asset: asset) }
            .buttonStyle(.plain)
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
                    entry("新的朋友", "contact_newfriend", .newFriends)
                    entry("仅聊天的朋友", "contact_chatonly", .chatOnly)
                    entry("群聊", "contact_group", .groups)
                    entry("标签", "contact_tag", .tags)
                    entry("公众号", "contact_official", .officialAccounts)
                    entry("服务号", "contact_service", .serviceAccounts)
                    entry("企业微信联系人", "contact_wecom", .wecom)
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
                            Button { openContact(contact) } label: {
                                HStack(spacing: 12) {
                                    AvatarView(contact: contact, size: 40)
                                    Text(contact.name).font(.system(size: 17)).foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("contact.row.\(contact.name)")
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
                    Button { showAdd = true } label: {
                        Image("nav_addfriend").resizable().frame(width: 24, height: 24)
                    }
                    .accessibilityLabel("添加朋友")
                }
            }
            .sheet(isPresented: $showAdd) { ContactEditView() }
            .alert(feature ?? "", isPresented: Binding(get: { feature != nil }, set: { if !$0 { feature = nil } })) {
                Button("知道了", role: .cancel) { }
            } message: { Text("当前版本支持一对一聊天，此功能暂未接入。") }
        }
    }
}

/// 通讯录顶部功能入口：40pt 彩色圆角图标 + 标题
struct ContactEntryRow: View {
    let title: String
    let asset: String

    var body: some View {
        HStack(spacing: 12) {
            Image(asset)
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
