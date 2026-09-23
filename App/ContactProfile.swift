import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 好友资料页（按实机截图：白色导航栏、昵称/微信号/地区、朋友资料、朋友圈、发消息）

struct ContactDetailView: View {
    @Bindable var contact: Contact
    @Environment(\.modelContext) private var context
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]
    @State private var openChat: Conversation?
    @State private var showCallChoice = false
    @State private var callRequest: CallRequest?

    private struct Thumb: Identifiable {
        let id: UUID
        let data: Data
    }

    /// 朋友圈入口右侧的最近几张照片
    private var recentPhotos: [Thumb] {
        let photos = moments.filter { $0.authorID == contact.id }.flatMap { $0.sortedPhotos }
        return Array(photos.compactMap { photo -> Thumb? in
            guard let data = photo.data else { return nil }
            return Thumb(id: photo.id, data: data)
        }.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                    if !contact.isMe {
                        Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5).padding(.leading, 16)
                        NavigationLink { FriendInfoView(contact: contact) } label: { friendInfoRow }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("contact.friendInfo")
                    }
                }
                .background(Color.cellBackground)

                WeChatGroup {
                    NavigationLink {
                        MomentsView(authorID: contact.id, title: contact.isMe ? "我的朋友圈" : contact.name)
                    } label: { momentsRow }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("contact.moments")
                }
                .padding(.top, 8)

                if !contact.isMe && !contact.isSystem {
                    WeChatGroup {
                        Button { openChat = context.conversation(with: contact) } label: {
                            actionLabel("发消息", systemImage: "message")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("contact.sendMessage")
                        Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)
                        Button { showCallChoice = true } label: {
                            actionLabel("音视频通话", systemImage: "phone.arrow.up.right")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("contact.call")
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.chatBackground)
        .navigationTitle("")
        .weChatNavigation()
        .toolbarBackground(Color.cellBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !contact.isMe {
                    NavigationLink { ContactSettingsView(contact: contact) } label: {
                        Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel("更多")
                    .accessibilityIdentifier("contact.more")
                }
            }
        }
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
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            AvatarView(contact: contact, size: 64)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(contact.name)
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(1)
                        .accessibilityIdentifier("contact.name")
                    GenderIcon(gender: contact.gender)
                    if contact.starred {
                        Image(systemName: "star.fill").font(.system(size: 13)).foregroundStyle(Color(hex: 0xFFC300))
                    }
                }
                .padding(.bottom, 3)
                if !contact.nickname.isEmpty && contact.nickname != contact.name {
                    infoLine("昵称：\(contact.nickname)")
                }
                infoLine("微信号：\(contact.handle)")
                if !contact.region.isEmpty { infoLine("地区：\(contact.region)") }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 32)
    }

    private func infoLine(_ text: String) -> some View {
        Text(text).font(.system(size: 15)).foregroundStyle(Color.wcSecondary).lineLimit(1)
    }

    private var friendInfoRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("朋友资料").font(.system(size: 17, weight: .semibold))
                Text("添加朋友的备注名、电话、标签、备忘、照片等，并设置朋友权限。")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.wcTips)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Chevron().padding(.top, 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private var momentsRow: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("朋友圈").font(.system(size: 17, weight: .semibold))
                .frame(width: 80, alignment: .leading)
            if !contact.chatOnly {
                HStack(spacing: 4) {
                    ForEach(recentPhotos) { photo in
                        if let image = UIImage(data: photo.data) {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(width: 48, height: 48).clipped()
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Chevron()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .padding(.vertical, recentPhotos.isEmpty || contact.chatOnly ? 0 : 16)
        .contentShape(Rectangle())
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).font(.system(size: 18))
            Text(title).font(.system(size: 17, weight: .semibold))
        }
        .foregroundStyle(Color.linkBlue)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .contentShape(Rectangle())
    }
}

/// 名字后面的性别标记：男蓝、女粉
struct GenderIcon: View {
    let gender: Int
    var body: some View {
        switch gender {
        case 1:
            Image(systemName: "person.fill").font(.system(size: 14)).foregroundStyle(Color(hex: 0x10AEFF))
                .accessibilityLabel("男")
        case 2:
            Image(systemName: "figure.stand.dress").font(.system(size: 15)).foregroundStyle(Color(hex: 0xF37E7D))
                .accessibilityLabel("女")
        default:
            EmptyView()
        }
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.wcTips)
            .frame(width: 12, height: 24)
    }
}

// MARK: - 通用行：标题 + 右侧值 + 箭头 / 开关

struct InfoRow: View {
    let title: String
    var value: String = ""
    var chevron = true
    var titleColor: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 17)).foregroundStyle(titleColor)
            Spacer(minLength: 8)
            if !value.isEmpty {
                Text(value).font(.system(size: 17)).foregroundStyle(Color.wcSecondary).lineLimit(1)
            }
            if chevron { Chevron() }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(Color.cellBackground)
        .contentShape(Rectangle())
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var id: String? = nil

    var body: some View {
        Toggle(isOn: $isOn) { Text(title).font(.system(size: 17)) }
            .tint(Color.brand)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(Color.cellBackground)
            .accessibilityIdentifier(id ?? title)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 14))
            .foregroundStyle(Color.wcSecondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, minHeight: 37, alignment: .bottomLeading)
    }
}

// MARK: - 资料页右上角 ··· → 设置

struct ContactSettingsView: View {
    @Bindable var contact: Contact
    @Environment(\.modelContext) private var context
    @State private var showRecommend = false
    @State private var confirmDelete = false
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                WeChatGroup {
                    NavigationLink { TextValueEditor(title: "设置备注", placeholder: "备注名", text: $contact.name) } label: {
                        InfoRow(title: "编辑备注")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("contactSettings.remark")
                    WeChatSeparator(leading: 16)
                    NavigationLink { FriendPermissionView(contact: contact) } label: { InfoRow(title: "设置权限") }
                        .buttonStyle(.plain)
                }
                WeChatGroup {
                    Button { showRecommend = true } label: { InfoRow(title: "把\(contact.pronoun)推荐给朋友") }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("contactSettings.recommend")
                }
                WeChatGroup { ToggleRow(title: "设为星标朋友", isOn: $contact.starred, id: "contactSettings.star") }
                WeChatGroup { ToggleRow(title: "加入黑名单", isOn: $contact.blocked, id: "contactSettings.block") }
                WeChatGroup {
                    NavigationLink { ComplaintView(target: contact.name) } label: { InfoRow(title: "投诉") }
                        .buttonStyle(.plain)
                }
                WeChatGroup {
                    Button { confirmDelete = true } label: {
                        Text("删除联系人").font(.system(size: 17)).foregroundStyle(Color(hex: 0xFA5151))
                            .frame(maxWidth: .infinity).frame(height: 56).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("contactSettings.delete")
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.chatBackground)
        .navigationTitle("设置")
        .weChatNavigation()
        .sheet(isPresented: $showRecommend) {
            ChatPickerSheet(preview: "[个人名片] \(contact.name)") { targets in
                for target in targets {
                    let message = context.addMessage(to: target, kind: .card, text: contact.name, fromMe: true)
                    message.cardContactID = contact.id
                }
                try? context.save()
                showToast("已发送")
            }
        }
        .confirmationDialog("将联系人“\(contact.name)”删除，同时删除与该联系人的聊天记录",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除联系人", role: .destructive) {
                let contact = contact
                NotificationCenter.default.post(name: .popToRoot, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    context.delete(contact)
                    try? context.save()
                }
            }
        }
        .overlay {
            if let toast {
                Text(toast).font(.system(size: 15)).foregroundStyle(.white)
                    .padding(20).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
            }
        }
    }

    private func showToast(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast = nil }
    }
}

// MARK: - 朋友资料（备注名、电话、标签、备忘、照片、权限、共同群聊、来源、添加时间）

struct FriendInfoView: View {
    @Bindable var contact: Contact
    @AppStorage("editMode") private var editMode = false
    @State private var photoCount = 0

    private static let sources = ["对方通过搜索账号添加", "通过搜索微信号添加", "通过扫一扫添加", "对方通过扫一扫添加",
                                  "通过群聊添加", "对方通过群聊添加", "通过名片分享添加", "通过手机号添加"]

    private var addedAt: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: contact.createdAt)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(title: "备注")
                WeChatGroup {
                    link("备注名", contact.name, id: "friendInfo.remark") {
                        TextValueEditor(title: "备注名", placeholder: "添加备注名", text: $contact.name)
                    }
                    WeChatSeparator(leading: 16)
                    link("电话", contact.phone, id: "friendInfo.phone") {
                        TextValueEditor(title: "电话", placeholder: "添加电话号码", text: $contact.phone, keyboard: .phonePad)
                    }
                    WeChatSeparator(leading: 16)
                    link("标签", contact.tags.joined(separator: "，"), id: "friendInfo.tags") { ContactTagsEditor(contact: contact) }
                    WeChatSeparator(leading: 16)
                    link("备忘", contact.memo, id: "friendInfo.memo") { MemoEditor(text: $contact.memo) }
                    WeChatSeparator(leading: 16)
                    link("照片", photoCount > 0 ? "\(photoCount) 张" : "", id: "friendInfo.photos") {
                        ContactPhotosView(contactID: contact.id)
                    }
                }
                SectionHeader(title: "权限")
                WeChatGroup {
                    link("权限", contact.chatOnly ? "仅聊天" : "聊天、朋友圈、微信运动等", id: "friendInfo.permission") {
                        FriendPermissionView(contact: contact)
                    }
                }
                SectionHeader(title: "更多信息")
                WeChatGroup {
                    NavigationLink { CommonGroupsView(contact: contact) } label: {
                        InfoRow(title: "我和\(contact.pronoun)的共同群聊", value: "\(contact.groups.count)个",
                                chevron: !contact.groups.isEmpty)
                    }
                    .buttonStyle(.plain)
                    .disabled(contact.groups.isEmpty)
                    .accessibilityIdentifier("friendInfo.groups")
                }
                WeChatGroup {
                    if editMode {
                        Menu {
                            ForEach(Self.sources, id: \.self) { source in Button(source) { contact.source = source } }
                        } label: { InfoRow(title: "来源", value: contact.sourceText, chevron: false) }
                        .buttonStyle(.plain)
                        WeChatSeparator(leading: 16)
                        DatePicker("添加时间", selection: $contact.createdAt, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .font(.system(size: 17))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                    } else {
                        InfoRow(title: "来源", value: contact.sourceText, chevron: false)
                        WeChatSeparator(leading: 16)
                        InfoRow(title: "添加时间", value: addedAt, chevron: false)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
        .background(Color.chatBackground)
        .navigationTitle("朋友资料")
        .weChatNavigation()
        .onAppear { photoCount = ContactPhotoStore.list(contact.id).count }
    }

    private func link<Destination: View>(_ title: String, _ value: String, id: String,
                                         @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink { destination() } label: { InfoRow(title: title, value: value) }
            .buttonStyle(.plain)
            .accessibilityIdentifier(id)
    }
}

/// 单行文本编辑（备注名、电话等），右上角“完成”返回
struct TextValueEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $value)
                .font(.system(size: 17))
                .keyboardType(keyboard)
                .focused($focused)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.cellBackground)
                .accessibilityIdentifier("valueEditor.field")
                .testingKeyboard()
            Spacer()
        }
        .padding(.top, 16)
        .background(Color.chatBackground)
        .navigationTitle(title)
        .weChatNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {
                    let trimmed = value.trimmingCharacters(in: .whitespaces)
                    // 备注名不能为空
                    if !(trimmed.isEmpty && title.contains("备注")) { text = trimmed }
                    dismiss()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.brand)
                .accessibilityIdentifier("valueEditor.done")
            }
        }
        .onAppear {
            value = text
            focused = true
        }
    }
}

struct MemoEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 17))
            .scrollContentBackground(.hidden)
            .padding(12)
            .frame(height: 200)
            .background(Color.cellBackground)
            .padding(.top, 16)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.chatBackground)
            .navigationTitle("备忘")
            .weChatNavigation()
    }
}

struct ContactTagsEditor: View {
    @Bindable var contact: Contact
    @Query(filter: #Predicate<Contact> { $0.isMe == false }) private var contacts: [Contact]
    @State private var newTag = ""

    private var allTags: [String] { Array(Set(contacts.flatMap(\.tags))).sorted() }

    var body: some View {
        Form {
            Section {
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
        .navigationTitle("标签")
        .weChatNavigation()
    }
}

/// 朋友资料 → 照片：保存在 Application Support/ContactPhotos/<id>/
enum ContactPhotoStore {
    static func list(_ id: UUID) -> [URL] {
        let dir = LocalFiles.contactPhotos(id)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func add(_ data: Data, to id: UUID) {
        let name = String(format: "%.0f", Date().timeIntervalSince1970 * 1000) + ".jpg"
        try? data.write(to: LocalFiles.contactPhotos(id).appending(path: name))
    }
}

struct ContactPhotosView: View {
    let contactID: UUID
    @State private var files: [URL] = []
    @State private var items: [PhotosPickerItem] = []
    @State private var viewer: ViewerImage?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                ForEach(files, id: \.self) { url in
                    if let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                            .clipped()
                            .onTapGesture { viewer = ViewerImage(image: image) }
                            .contextMenu {
                                Button("删除", systemImage: "trash", role: .destructive) {
                                    try? FileManager.default.removeItem(at: url)
                                    reload()
                                }
                            }
                    }
                }
                PhotosPicker(selection: $items, maxSelectionCount: 9, matching: .images) {
                    Rectangle().fill(Color.cellBackground)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Image(systemName: "plus").font(.system(size: 28, weight: .light)).foregroundStyle(Color.wcTips))
                }
                .accessibilityLabel("添加照片")
            }
            .padding(16)
            Text("可添加名片或相关图片，仅保存在本机。")
                .font(.system(size: 14)).foregroundStyle(Color.wcTips)
        }
        .background(Color.chatBackground)
        .navigationTitle("照片")
        .weChatNavigation()
        .onAppear(perform: reload)
        .onChange(of: items) { _, picked in
            guard !picked.isEmpty else { return }
            Task {
                for item in picked {
                    if let raw = try? await item.loadTransferable(type: Data.self),
                       let data = ImageUtil.downsampledJPEG(raw, maxPixel: 1600) {
                        ContactPhotoStore.add(data, to: contactID)
                    }
                }
                items = []
                reload()
            }
        }
        .fullScreenCover(item: $viewer) { ImageViewer(image: $0.image) }
    }

    private func reload() { files = ContactPhotoStore.list(contactID) }
}

struct CommonGroupsView: View {
    let contact: Contact

    var body: some View {
        List(contact.groups) { group in
            NavigationLink { ChatView(conversation: group) } label: {
                HStack(spacing: 12) {
                    ConversationAvatar(conversation: group, size: 40)
                    Text(group.displayTitle)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("共同群聊")
        .weChatNavigation()
    }
}

struct FriendPermissionView: View {
    @Bindable var contact: Contact

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(title: "设置朋友权限")
                WeChatGroup {
                    row("聊天、朋友圈、微信运动等", selected: !contact.chatOnly) { contact.chatOnly = false }
                    WeChatSeparator(leading: 16)
                    row("仅聊天", selected: contact.chatOnly) { contact.chatOnly = true }
                }
                Text("设为仅聊天后，朋友圈中不再显示对方的动态。")
                    .font(.system(size: 14)).foregroundStyle(Color.wcTips)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
        .background(Color.chatBackground)
        .navigationTitle("朋友权限")
        .weChatNavigation()
    }

    private func row(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 17)).foregroundStyle(.primary)
                Spacer()
                if selected { Image(systemName: "checkmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.brand) }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 投诉：仅在本机记录，不会发送
struct ComplaintView: View {
    let target: String
    @State private var submitted: String?

    private let reasons = ["发布不适当内容对我造成骚扰", "存在欺诈骗钱行为", "此账号可能被盗用了", "存在侵权行为",
                           "发布仿冒品信息", "冒充他人", "侵犯未成年人权益", "粉丝无底线追星行为"]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(title: "请选择投诉该账号的原因：")
                WeChatGroup {
                    ForEach(reasons.indices, id: \.self) { index in
                        Button { submitted = reasons[index] } label: { InfoRow(title: reasons[index]) }
                            .buttonStyle(.plain)
                        if index < reasons.count - 1 { WeChatSeparator(leading: 16) }
                    }
                }
            }
        }
        .background(Color.chatBackground)
        .navigationTitle("投诉")
        .weChatNavigation()
        .alert("已记录", isPresented: Binding(get: { submitted != nil }, set: { if !$0 { submitted = nil } })) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("本地演示不会真的提交投诉。原因：\(submitted ?? "")")
        }
    }
}

// MARK: - 选择聊天（推荐名片、转发消息）

struct ChatPickerSheet: View {
    /// 当前所在会话，列表中标注“当前聊天”
    var currentID: UUID? = nil
    /// 确认框里展示的内容，如“[个人名片] 张三”
    let preview: String
    var onSend: ([Conversation]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var conversations: [Conversation]
    @State private var search = ""
    @State private var multiSelect = false
    @State private var selected: Set<UUID> = []
    @State private var pending: [Conversation] = []
    @State private var showConfirm = false
    @State private var showCreate = false
    @State private var notice: String?

    private var recent: [Conversation] {
        conversations.filter { $0.isGroup || $0.peer != nil }.sorted { $0.lastActivity > $1.lastActivity }
    }
    private var filtered: [Conversation] {
        search.isEmpty ? recent : recent.filter { $0.title.localizedStandardContains(search) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    WeChatSearchBar(text: $search)
                    if search.isEmpty && !recent.isEmpty {
                        Text("最近转发").font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(recent.prefix(8)) { conversation in
                                    Button { choose(conversation) } label: {
                                        VStack(spacing: 8) {
                                            ConversationAvatar(conversation: conversation, size: 56)
                                            Text(conversation.title)
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.wcSecondary)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .frame(width: 60)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 28)
                    }
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text("最近聊天").font(.system(size: 17, weight: .semibold))
                            Spacer(minLength: 4)
                            Button("创建聊天") { showCreate = true }
                                .accessibilityIdentifier("picker.create")
                            Rectangle().fill(Color.primary.opacity(0.15)).frame(width: 0.5, height: 16)
                            Button("转到企业微信") { notice = "转到企业微信" }
                            Button("其他应用") { notice = "其他应用" }
                        }
                        .font(.system(size: 16))
                        .foregroundStyle(Color.linkBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        ForEach(filtered) { conversation in
                            Button { choose(conversation) } label: { row(conversation) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("picker.chat.\(conversation.title)")
                        }
                    }
                    .background(Color.cellBackground,
                                in: UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous))
                }
            }
            .background(Color.chatBackground)
            .navigationTitle("选择聊天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.foregroundStyle(.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if multiSelect {
                        Button(selected.isEmpty ? "完成" : "完成(\(selected.count))") {
                            pending = recent.filter { selected.contains($0.id) }
                            showConfirm = !pending.isEmpty
                        }
                        .foregroundStyle(Color.brand)
                        .disabled(selected.isEmpty)
                    } else {
                        Button("多选") { multiSelect = true }.foregroundStyle(.primary)
                    }
                }
            }
            .alert("发送给：\(pending.map(\.title).joined(separator: "、"))", isPresented: $showConfirm) {
                Button("取消", role: .cancel) {}
                Button("发送") {
                    onSend(pending)
                    dismiss()
                }
            } message: {
                Text(preview)
            }
            .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("知道了", role: .cancel) {}
            } message: { Text("本地演示未接入其他应用。") }
            .sheet(isPresented: $showCreate) {
                CardPickerSheet(title: "创建聊天") { contact in
                    let conversation = context.conversation(with: contact)
                    try? context.save()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { choose(conversation) }
                }
            }
        }
    }

    private func choose(_ conversation: Conversation) {
        if multiSelect {
            if selected.contains(conversation.id) { selected.remove(conversation.id) } else { selected.insert(conversation.id) }
        } else {
            pending = [conversation]
            showConfirm = true
        }
    }

    private func row(_ conversation: Conversation) -> some View {
        HStack(spacing: 12) {
            if multiSelect {
                Image(systemName: selected.contains(conversation.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected.contains(conversation.id) ? Color.brand : Color.wcTips)
            }
            ConversationAvatar(conversation: conversation, size: 40)
            Text(conversation.title).font(.system(size: 17)).lineLimit(1)
            if conversation.isGroup {
                Text("(\(conversation.members.count + 1)人)").font(.system(size: 17)).foregroundStyle(Color.wcTips)
            }
            Spacer(minLength: 8)
            if conversation.id == currentID {
                Text("当前聊天").font(.system(size: 16)).foregroundStyle(Color.wcTips)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5).padding(.leading, 68)
        }
    }
}
