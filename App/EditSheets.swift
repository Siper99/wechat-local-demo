import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 编辑单条消息

struct MessageEditSheet: View {
    @Bindable var message: Message
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var isSystem: Binding<Bool> {
        Binding(get: { message.kind == .system },
                set: { message.kind = $0 ? .system : .text })
    }

    var body: some View {
        NavigationStack {
            Form {
                if message.kind != .system {
                    Section("发送方") {
                        Picker("发送方", selection: $message.fromMe) {
                            Text("对方").tag(false)
                            Text("我").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if message.kind != .image {
                    Section("内容") {
                        TextField("消息内容", text: $message.text, axis: .vertical)
                            .lineLimit(3...10)
                        Toggle("显示为灰色系统提示", isOn: isSystem)
                    }
                }
                Section("时间") {
                    DatePicker("发送时间", selection: $message.sentAt)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
                Section {
                    Button("删除这条消息", role: .destructive) { onDelete() }
                }
            }
            .navigationTitle("编辑消息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 会话设置（聊天页右上角 ···）

struct ConversationSettingsView: View {
    @Bindable var conversation: Conversation
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            Form {
                if let peer = conversation.peer {
                    Section("对方资料") { ContactFields(contact: peer) }
                }
                Section {
                    Toggle("置顶聊天", isOn: $conversation.pinned)
                    Toggle("消息免打扰", isOn: $conversation.muted)
                    Stepper("未读数：\(conversation.unread)", value: $conversation.unread, in: 0...999)
                }
                Section {
                    Button("清空聊天记录", role: .destructive) { confirmClear = true }
                }
            }
            .navigationTitle("聊天信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .confirmationDialog("确定清空聊天记录？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清空", role: .destructive) {
                    let messages = conversation.messages
                    messages.forEach { context.delete($0) }
                    try? context.save()
                }
            }
        }
    }
}

struct ContactFields: View {
    @Bindable var contact: Contact

    var body: some View {
        HStack(spacing: 14) {
            AvatarPicker(data: $contact.avatarData, name: contact.name, size: 56)
            TextField("昵称", text: $contact.name)
                .font(.system(size: 17))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 新建 / 编辑联系人（也用于"我"的资料）

struct ContactEditView: View {
    let contact: Contact?
    var onSave: ((Contact) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var avatarData: Data?

    init(contact: Contact? = nil, onSave: ((Contact) -> Void)? = nil) {
        self.contact = contact
        self.onSave = onSave
        _name = State(initialValue: contact?.name ?? "")
        _avatarData = State(initialValue: contact?.avatarData)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        AvatarPicker(data: $avatarData, name: trimmed.isEmpty ? "?" : trimmed, size: 64)
                        TextField("昵称", text: $name).font(.system(size: 17))
                    }
                    .padding(.vertical, 6)
                } footer: {
                    Text("点头像可从相册选择图片")
                }
            }
            .navigationTitle(contact == nil ? "新建联系人" : "编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(trimmed.isEmpty)
                }
            }
        }
    }

    private func save() {
        if let contact {
            contact.name = trimmed
            contact.avatarData = avatarData
            onSave?(contact)
        } else {
            let newContact = Contact(name: trimmed, avatarData: avatarData)
            context.insert(newContact)
            try? context.save()
            onSave?(newContact)
        }
        dismiss()
    }
}

struct AvatarPicker: View {
    @Binding var data: Data?
    var name: String
    var size: CGFloat = 56
    @State private var item: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            AvatarView(name: name, data: data, size: size)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: size * 0.32))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                        .offset(x: 4, y: 4)
                }
        }
        .buttonStyle(.borderless)
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task {
                if let raw = try? await newItem.loadTransferable(type: Data.self) {
                    data = ImageUtil.downsampledJPEG(raw, maxPixel: 400)
                }
                item = nil
            }
        }
    }
}

// MARK: - 模拟对方回复

struct SimulateReplySheet: View {
    var onStart: (String, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var delay = 3

    var body: some View {
        NavigationStack {
            Form {
                Section("对方将发送") {
                    TextField("消息内容", text: $text, axis: .vertical).lineLimit(2...6)
                }
                Section {
                    Stepper("\(delay) 秒后到达", value: $delay, in: 1...120)
                } footer: {
                    Text("等待期间标题显示\u{201C}对方正在输入...\u{201D}。可以先退回会话列表，消息到达后会显示未读。")
                }
            }
            .navigationTitle("模拟对方回复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始") {
                        onStart(text.trimmingCharacters(in: .whitespacesAndNewlines), delay)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 看大图

struct ImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image).resizable().scaledToFit()
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .statusBarHidden()
    }
}
