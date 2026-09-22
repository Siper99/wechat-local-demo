import SwiftUI
import SwiftData

struct ContactsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Contact> { $0.isMe == false }) private var contacts: [Contact]
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

    var body: some View {
        ScrollViewReader { proxy in
            List {
                WeChatSearchBar(text: $search)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                Section {
                    Button { showAdd = true } label: { IconRow(icon: "person.badge.plus", color: .orange, title: "新的朋友") }.buttonStyle(.plain)
                    Button { feature = "群聊" } label: { IconRow(icon: "person.3.fill", color: Color.brand, title: "群聊") }.buttonStyle(.plain)
                    Button { feature = "标签" } label: { IconRow(icon: "tag.fill", color: .blue, title: "标签") }.buttonStyle(.plain)
                    Button { feature = "公众号" } label: { IconRow(icon: "person.crop.square", color: .blue, title: "公众号") }.buttonStyle(.plain)
                }
                ForEach(sections, id: \.letter) { section in
                    Text(section.letter)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 24)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.chatBackground)
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
                VStack(spacing: 4) {
                    ForEach(sections, id: \.letter) { section in
                        Button(section.letter) { withAnimation { proxy.scrollTo(section.letter, anchor: .top) } }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }.padding(.trailing, 3)
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
