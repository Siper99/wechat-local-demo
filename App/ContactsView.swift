import SwiftUI
import SwiftData

struct ContactsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Contact> { $0.isMe == false }) private var contacts: [Contact]
    @State private var showAdd = false

    private var sections: [(letter: String, contacts: [Contact])] {
        Dictionary(grouping: contacts) { PinyinIndex.letter(for: $0.name) }
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
        NavigationStack {
            List {
                Section {
                    IconRow(icon: "person.badge.plus", color: .orange, title: "新的朋友")
                    IconRow(icon: "person.3.fill", color: Color.brand, title: "群聊")
                    IconRow(icon: "tag.fill", color: .blue, title: "标签")
                }
                ForEach(sections, id: \.letter) { section in
                    Section(section.letter) {
                        ForEach(section.contacts) { contact in
                            NavigationLink(value: contact) {
                                HStack(spacing: 12) {
                                    AvatarView(contact: contact, size: 40)
                                    Text(contact.name).font(.system(size: 17))
                                }
                                .padding(.vertical, 2)
                            }
                            .swipeActions {
                                Button("删除", role: .destructive) {
                                    context.delete(contact)
                                    try? context.save()
                                }
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Contact.self) { ContactDetailView(contact: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "person.badge.plus") }
                }
            }
            .sheet(isPresented: $showAdd) { ContactEditView() }
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
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color))
            Text(title).font(.system(size: 17))
        }
        .padding(.vertical, 2)
    }
}
