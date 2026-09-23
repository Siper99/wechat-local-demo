import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 朋友圈

/// authorID 为空时显示全部动态；传入某人 id 时只看此人（我的朋友圈 / 好友朋友圈）
struct MomentsView: View {
    var authorID: UUID? = nil
    var title = "朋友圈"

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Moment.createdAt, order: .reverse) private var allMoments: [Moment]
    @Query private var contacts: [Contact]
    @AppStorage("momentsCoverVersion") private var coverVersion = 0

    @State private var showCompose = false
    @State private var actionMenuFor: UUID?
    @State private var commentTarget: CommentTarget?
    @State private var commentText = ""
    @State private var viewerImage: ViewerImage?
    @State private var coverItem: PhotosPickerItem?
    @State private var showCoverPicker = false
    @State private var headerMinY: CGFloat = 0
    @FocusState private var commentFocused: Bool

    private var me: Contact? { contacts.first { $0.isMe } }
    private var hiddenAuthors: Set<UUID> { Set(contacts.filter(\.chatOnly).map(\.id)) }

    private var moments: [Moment] {
        allMoments.filter { moment in
            if let authorID { return moment.authorID == authorID }
            guard let id = moment.authorID else { return true }
            return !hiddenAuthors.contains(id)
        }
    }

    private var owner: Contact? {
        guard let authorID else { return me }
        return contacts.first { $0.id == authorID }
    }

    private var isOwnPage: Bool { authorID == nil || authorID == me?.id }
    /// 封面滚出屏幕后显示实心导航栏
    private var solidBar: Bool { headerMinY < -220 }

    var body: some View {
        ZStack(alignment: .top) {
            feed.ignoresSafeArea(edges: .top)
            topBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { if commentTarget != nil { commentBar } }
        .sheet(isPresented: $showCompose) { MomentComposeView() }
        .fullScreenCover(item: $viewerImage) { ImageViewer(image: $0.image) }
        .photosPicker(isPresented: $showCoverPicker, selection: $coverItem, matching: .images)
        .onChange(of: coverItem) { _, item in
            guard let item else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self),
                   let jpeg = ImageUtil.downsampledJPEG(raw, maxPixel: 1400) {
                    try? jpeg.write(to: LocalFiles.momentsCover, options: .atomic)
                    coverVersion += 1
                }
                coverItem = nil
            }
        }
    }

    private var feed: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                LazyVStack(spacing: 0) {
                    ForEach(moments) { moment in
                        MomentCell(
                            moment: moment,
                            author: contacts.first { $0.id == moment.authorID },
                            myName: me?.name ?? "我",
                            isMine: moment.authorID == me?.id,
                            menuOpen: actionMenuFor == moment.id,
                            onToggleMenu: {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    actionMenuFor = actionMenuFor == moment.id ? nil : moment.id
                                }
                            },
                            onLike: { toggleLike(moment) },
                            onComment: { startComment(moment, replyTo: nil) },
                            onReply: { startComment(moment, replyTo: $0) },
                            onDeleteComment: { comment in
                                context.delete(comment)
                                try? context.save()
                            },
                            onDelete: {
                                context.delete(moment)
                                try? context.save()
                            },
                            onTapImage: { viewerImage = ViewerImage(image: $0) }
                        )
                        Divider()
                    }
                    if moments.isEmpty {
                        Text(isOwnPage ? "点右上角相机，发表第一条朋友圈" : "暂无朋友圈")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 60)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .coordinateSpace(name: "moments")
        .background(Color(.systemBackground))
        .scrollDismissesKeyboard(.interactively)
        .onPreferenceChange(HeaderOffsetKey.self) { headerMinY = $0 }
    }

    // MARK: 封面

    private var header: some View {
        ZStack(alignment: .bottomTrailing) {
            cover
                .frame(height: 320)
                .frame(maxWidth: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { if isOwnPage { showCoverPicker = true } }
                .accessibilityLabel(isOwnPage ? "更换朋友圈封面" : "朋友圈封面")
            HStack(alignment: .bottom, spacing: 14) {
                Text(owner?.name ?? "我")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .padding(.bottom, 22)
                AvatarView(contact: owner, size: 70)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 1))
            }
            .padding(.trailing, 16)
            .offset(y: 24)
        }
        .padding(.bottom, 44)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: HeaderOffsetKey.self, value: proxy.frame(in: .named("moments")).minY)
        })
    }

    @ViewBuilder private var cover: some View {
        let _ = coverVersion
        if let data = try? Data(contentsOf: LocalFiles.momentsCover), let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            LinearGradient(colors: [Color(hex: 0x3A4A5C), Color(hex: 0x8AA1B1)], startPoint: .top, endPoint: .bottom)
                .overlay {
                    if isOwnPage {
                        Text("轻点设置相册封面").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                    }
                }
        }
    }

    // MARK: 顶栏（透明 → 滚动后实心）

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .accessibilityLabel("返回")
            .accessibilityIdentifier("moments.back")
            Spacer()
            if solidBar {
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            Spacer()
            if isOwnPage {
                Button { showCompose = true } label: {
                    Image(systemName: "camera").font(.system(size: 19))
                        .frame(width: 44, height: 44, alignment: .trailing)
                }
                .accessibilityLabel("发表朋友圈")
                .accessibilityIdentifier("moments.compose")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(solidBar ? Color.primary : Color.white)
        .shadow(color: solidBar ? .clear : .black.opacity(0.35), radius: 2)
        .padding(.horizontal, 12)
        .background(alignment: .bottom) {
            if solidBar { Color.chatBackground.ignoresSafeArea(edges: .top) }
        }
        .animation(.easeOut(duration: 0.15), value: solidBar)
    }

    // MARK: 评论输入

    private var commentBar: some View {
        HStack(spacing: 8) {
            TextField(commentTarget?.replyTo.map { "回复\($0)：" } ?? "评论", text: $commentText, axis: .vertical)
                .lineLimit(1...4)
                .focused($commentFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.inputField, in: RoundedRectangle(cornerRadius: 6))
                .submitLabel(.send)
                .onSubmit(sendComment)
                .accessibilityIdentifier("moments.commentField")
                    .testingKeyboard()
            Button("发送", action: sendComment)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 5).fill(commentText.isEmpty ? Color.gray.opacity(0.4) : Color.brand))
                .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("moments.commentSend")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.inputBar)
    }

    // MARK: 动作

    private func toggleLike(_ moment: Moment) {
        moment.likedByMe.toggle()
        actionMenuFor = nil
        try? context.save()
    }

    private func startComment(_ moment: Moment, replyTo: String?) {
        actionMenuFor = nil
        commentTarget = CommentTarget(momentID: moment.id, replyTo: replyTo)
        commentText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { commentFocused = true }
    }

    private func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let target = commentTarget,
              let moment = allMoments.first(where: { $0.id == target.momentID }) else { return }
        let comment = MomentComment(authorName: me?.name ?? "我", fromMe: true, text: text, replyTo: target.replyTo)
        context.insert(comment)
        comment.moment = moment
        try? context.save()
        commentText = ""
        commentTarget = nil
        commentFocused = false
    }
}

private struct CommentTarget {
    let momentID: UUID
    let replyTo: String?
}

private struct HeaderOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - 单条动态

struct MomentCell: View {
    let moment: Moment
    let author: Contact?
    let myName: String
    let isMine: Bool
    let menuOpen: Bool
    var onToggleMenu: () -> Void
    var onLike: () -> Void
    var onComment: () -> Void
    var onReply: (String) -> Void
    var onDeleteComment: (MomentComment) -> Void
    var onDelete: () -> Void
    var onTapImage: (UIImage) -> Void

    @State private var confirmDelete = false

    private var likeNames: [String] { (moment.likedByMe ? [myName] : []) + moment.likes }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(name: author?.name ?? moment.authorName, data: author?.avatarData, size: 42)
            VStack(alignment: .leading, spacing: 6) {
                Text(author?.name ?? moment.authorName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.linkBlue)
                if !moment.text.isEmpty {
                    Text(moment.text)
                        .font(.system(size: 16))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if !moment.photos.isEmpty { photoGrid.padding(.top, 2) }
                if !moment.location.isEmpty {
                    Text(moment.location).font(.system(size: 13)).foregroundStyle(Color.linkBlue)
                }
                HStack(spacing: 12) {
                    Text(RelativeTime.label(moment.createdAt)).font(.system(size: 13)).foregroundStyle(.secondary)
                    if isMine {
                        Button("删除") { confirmDelete = true }
                            .font(.system(size: 13))
                            .foregroundStyle(Color.linkBlue)
                    }
                    Spacer()
                    actionMenu
                    Button(action: onToggleMenu) {
                        HStack(spacing: 3) {
                            Circle().frame(width: 4, height: 4)
                            Circle().frame(width: 4, height: 4)
                        }
                        .foregroundStyle(Color.linkBlue)
                        .frame(width: 32, height: 20)
                        .background(Color.dynamic(0xF7F7F7, 0x2C2C2C), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("点赞或评论")
                }
                .padding(.top, 2)
                if !likeNames.isEmpty || !moment.comments.isEmpty { interactions }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .confirmationDialog("删除这条朋友圈？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive, action: onDelete)
        }
    }

    // 点"··"后向左展开的深色操作条
    @ViewBuilder private var actionMenu: some View {
        if menuOpen {
            HStack(spacing: 0) {
                Button(action: onLike) {
                    Label(moment.likedByMe ? "取消" : "赞", systemImage: moment.likedByMe ? "heart.fill" : "heart")
                        .frame(width: 88, height: 36)
                }
                .accessibilityIdentifier("moments.like")
                Rectangle().fill(.white.opacity(0.15)).frame(width: 0.5, height: 20)
                Button(action: onComment) {
                    Label("评论", systemImage: "bubble.left")
                        .frame(width: 88, height: 36)
                }
                .accessibilityIdentifier("moments.comment")
            }
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .background(Color(hex: 0x4C4C4C), in: RoundedRectangle(cornerRadius: 5))
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    // MARK: 图片九宫格

    private struct PhotoItem: Identifiable {
        let id: UUID
        let image: UIImage
    }

    private var images: [PhotoItem] {
        moment.sortedPhotos.compactMap { photo in
            ImageCache.image(for: photo.id, data: photo.data).map { PhotoItem(id: photo.id, image: $0) }
        }
    }

    @ViewBuilder private var photoGrid: some View {
        let items = images
        if items.count == 1, let only = items.first {
            let size = fitted(only.image.size)
            Image(uiImage: only.image).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .onTapGesture { onTapImage(only.image) }
        } else {
            let columns = items.count == 4 ? 2 : 3
            let side: CGFloat = 86
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: 5), count: columns), alignment: .leading, spacing: 5) {
                ForEach(items) { item in
                    Image(uiImage: item.image).resizable().scaledToFill()
                        .frame(width: side, height: side).clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { onTapImage(item.image) }
                }
            }
            .frame(width: CGFloat(columns) * side + CGFloat(columns - 1) * 5, alignment: .leading)
        }
    }

    private func fitted(_ size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: 180, height: 180) }
        let scale = min(200 / size.width, 200 / size.height)
        return CGSize(width: max(80, size.width * scale), height: max(80, size.height * scale))
    }

    // MARK: 点赞与评论

    private var interactions: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !likeNames.isEmpty {
                (Text(Image(systemName: "heart")).foregroundStyle(Color.linkBlue)
                 + Text(" " + likeNames.joined(separator: "，")).foregroundStyle(Color.linkBlue).fontWeight(.medium))
                    .font(.system(size: 14))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                if !moment.comments.isEmpty { Divider() }
            }
            ForEach(moment.sortedComments) { comment in
                commentLine(comment)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture { if !comment.fromMe { onReply(comment.authorName) } }
                    .contextMenu {
                        if !comment.fromMe {
                            Button("回复", systemImage: "arrowshape.turn.up.left") { onReply(comment.authorName) }
                        }
                        Button("复制", systemImage: "doc.on.doc") { UIPasteboard.general.string = comment.text }
                        if comment.fromMe || isMine {
                            Button("删除", systemImage: "trash", role: .destructive) { onDeleteComment(comment) }
                        }
                    }
            }
            .padding(.vertical, moment.comments.isEmpty ? 0 : 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dynamic(0xF7F7F7, 0x202020), in: RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .topLeading) {
            // 指向头像方向的小三角
            Triangle().fill(Color.dynamic(0xF7F7F7, 0x202020)).frame(width: 12, height: 8).offset(x: 12, y: -6)
        }
        .padding(.top, 4)
    }

    private func commentLine(_ comment: MomentComment) -> Text {
        let name = Text(comment.authorName).foregroundStyle(Color.linkBlue).fontWeight(.medium)
        if let reply = comment.replyTo {
            return name + Text("回复") + Text(reply).foregroundStyle(Color.linkBlue).fontWeight(.medium) + Text("：" + comment.text)
        }
        return name + Text("：" + comment.text)
    }
}

// MARK: - 发表朋友圈

struct MomentComposeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("editMode") private var editMode = false
    @Query(sort: \Contact.name) private var contacts: [Contact]

    @State private var text = ""
    @State private var photos: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var location = ""
    @State private var authorID: UUID?
    @State private var postedAt = Date()
    @State private var visibility = "公开"

    private var me: Contact? { contacts.first { $0.isMe } }
    private var canPost: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("这一刻的想法...", text: $text, axis: .vertical)
                        .lineLimit(4...12)
                        .accessibilityIdentifier("moments.composeText")
                    .testingKeyboard()
                    photoPicker
                }
                Section {
                    HStack {
                        Label("所在位置", systemImage: "location")
                        TextField("不显示", text: $location).multilineTextAlignment(.trailing)
                    }
                    Picker(selection: $visibility) {
                        ForEach(["公开", "私密", "部分可见"], id: \.self) { Text($0) }
                    } label: { Label("谁可以看", systemImage: "person") }
                }
                if editMode {
                    Section("仿真设置") {
                        Picker("发布者", selection: $authorID) {
                            Text(me?.name ?? "我").tag(me?.id)
                            ForEach(contacts.filter { !$0.isMe && !$0.isSystem }) { Text($0.name).tag(Optional($0.id)) }
                        }
                        DatePicker("发布时间", selection: $postedAt)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: post) {
                        Text("发表")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(RoundedRectangle(cornerRadius: 5).fill(canPost ? Color.brand : Color.gray.opacity(0.4)))
                    }
                    .disabled(!canPost)
                    .accessibilityIdentifier("moments.post")
                }
            }
            .onAppear { if authorID == nil { authorID = me?.id } }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    for item in items where photos.count < 9 {
                        if let raw = try? await item.loadTransferable(type: Data.self),
                           let jpeg = ImageUtil.downsampledJPEG(raw, maxPixel: 1400) {
                            photos.append(jpeg)
                        }
                    }
                    pickerItems = []
                }
            }
        }
    }

    private var photoPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(photos.indices, id: \.self) { index in
                if let image = UIImage(data: photos[index]) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity).aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .overlay(alignment: .topTrailing) {
                            Button { photos.remove(at: index) } label: {
                                Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .padding(3)
                        }
                }
            }
            if photos.count < 9 {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 9 - photos.count, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 0, maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        .background(Color.dynamic(0xF2F2F2, 0x2C2C2C))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加图片")
            }
        }
        .padding(.vertical, 6)
    }

    private func post() {
        let author = contacts.first { $0.id == authorID } ?? me
        let moment = Moment(author: author, text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                            createdAt: editMode ? postedAt : .now)
        moment.location = location.trimmingCharacters(in: .whitespaces)
        context.insert(moment)
        for (index, data) in photos.enumerated() {
            let photo = MomentPhoto(index: index, data: data)
            context.insert(photo)
            photo.moment = moment
        }
        try? context.save()
        dismiss()
    }
}
