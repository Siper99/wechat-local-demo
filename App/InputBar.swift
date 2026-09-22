import SwiftUI
import PhotosUI

enum InputPanel {
    case none, emoji, more
}

struct InputBar: View {
    @Binding var draft: String
    @Binding var panel: InputPanel
    @Binding var sendAsMe: Bool
    var inputFocused: FocusState<Bool>.Binding
    let editMode: Bool
    var onSend: () -> Void
    var onImages: ([Data]) -> Void
    var onSimulate: () -> Void
    var onLocation: () -> Void = {}

    @State private var showPhotos = false
    @State private var voiceInput = false
    @State private var featureNotice: String?
    @State private var showCamera = false

    private static let emojis = "😀😁😂🤣😊😍😘😎🤔😅😭😡👍👎👏🙏💪🤝🎉❤️💔🌹☕️🍺🎂🔥✨😴🤗😳😱🙄😏😬🤐😷🤒😇🥳🥺😤👌✌️🙈🌙☀️🍉🐶🐱".map(String.init)

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if editMode { senderSwitch }
            HStack(alignment: .bottom, spacing: 8) {
                barIcon(voiceInput ? "keyboard" : "mic.circle", asset: voiceInput ? nil : "chat_send_voice") {
                    voiceInput.toggle()
                    panel = .none
                    inputFocused.wrappedValue = !voiceInput
                }.accessibilityLabel(voiceInput ? "切换键盘" : "切换语音")
                if voiceInput {
                    // 8.0.78 灰度样式：无描边、更圆润扁平，右侧独立的“语音转文字”图标
                    Text("按住 说话")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color.inputField, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onLongPressGesture { featureNotice = "语音消息" }
                        .overlay(alignment: .trailing) {
                            Button { featureNotice = "语音转文字" } label: {
                                Image(systemName: "character.bubble")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, height: 40)
                            }
                            .accessibilityLabel("语音转文字")
                        }
                } else {
                    TextField("", text: $draft, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(1...5)
                    .focused(inputFocused)
                    .submitLabel(.send)
                    .accessibilityIdentifier("chat.input")
                    .accessibilityLabel("消息输入框")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.inputField))
                    .onSubmit(onSend)
                }
                barIcon(panel == .emoji ? "keyboard" : "face.smiling", asset: panel == .emoji ? nil : "chat_send_emoji") { voiceInput = false; toggle(.emoji) }
                    .accessibilityLabel("表情")
                if draft.isEmpty {
                    barIcon("plus.circle", asset: "chat_send_more") { voiceInput = false; toggle(.more) }
                        .accessibilityLabel("更多功能")
                } else {
                    Button("发送", action: onSend)
                        .accessibilityIdentifier("chat.send")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.brand))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            switch panel {
            case .emoji: emojiPanel
            case .more: morePanel
            case .none: EmptyView()
            }
        }
        .background(Color.inputBar.ignoresSafeArea(edges: .bottom))
        .sheet(isPresented: $showCamera) {
            CameraPicker { data in onImages([data]); showCamera = false }
        }
        .alert(featureNotice ?? "", isPresented: Binding(get: { featureNotice != nil }, set: { if !$0 { featureNotice = nil } })) {
            Button("知道了", role: .cancel) { }
        } message: { Text("此功能尚未接入；当前支持文字、图片和本地消息编辑。") }
        .sheet(isPresented: $showPhotos) {
            PhotoSendSheet { images in
                onImages(images)
                withAnimation { panel = .none }
            }
        }
    }

    private var senderSwitch: some View {
        HStack(spacing: 8) {
            Text("发送身份")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("发送方", selection: $sendAsMe) {
                Text("对方").tag(false)
                Text("我").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func barIcon(_ name: String, asset: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let asset {
                    Image(asset).resizable().scaledToFit().frame(width: 28, height: 28)
                } else {
                    Image(systemName: name).font(.system(size: 27, weight: .light))
                }
            }.foregroundStyle(.primary).frame(width: 30, height: 38)
        }
    }

    private func toggle(_ target: InputPanel) {
        withAnimation(.easeOut(duration: 0.2)) {
            if panel == target {
                panel = .none
                inputFocused.wrappedValue = true
            } else {
                inputFocused.wrappedValue = false
                panel = target
            }
        }
    }

    // MARK: - 表情面板

    private var emojiPanel: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 14) {
                ForEach(Self.emojis, id: \.self) { emoji in
                    Button { draft += emoji } label: { Text(emoji).font(.system(size: 30)) }
                }
            }
            .padding(14)
            .padding(.bottom, 44)
        }
        .frame(height: 230)
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 8) {
                Button {
                    if !draft.isEmpty { draft.removeLast() }
                } label: {
                    Image(systemName: "delete.left")
                        .frame(width: 52, height: 36)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.inputField))
                }
                .foregroundStyle(.primary)
                Button("发送", action: onSend)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 36)
                    .background(RoundedRectangle(cornerRadius: 5).fill(draft.isEmpty ? Color.gray.opacity(0.5) : Color.brand))
                    .disabled(draft.isEmpty)
            }
            .padding(12)
        }
    }

    // MARK: - ＋ 面板

    private var morePanel: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 18) {
            Button { showPhotos = true } label: { tile("photo", "相册") }
                .buttonStyle(.plain)
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
                else { featureNotice = "相机不可用" }
            } label: { tile("camera", "拍摄") }.buttonStyle(.plain)
            Button { featureNotice = "视频通话" } label: { tile("video", "视频通话") }.buttonStyle(.plain)
            Button { panel = .none; onLocation() } label: { tile("location", "位置") }.buttonStyle(.plain)
            Button { featureNotice = "红包" } label: { tile("gift", "红包") }.buttonStyle(.plain)
            Button { featureNotice = "转账" } label: { tile("arrow.left.arrow.right", "转账") }.buttonStyle(.plain)
            Button { featureNotice = "名片" } label: { tile("person.crop.rectangle", "名片") }.buttonStyle(.plain)
            VStack(spacing: 6) {
                PasteButton(payloadType: String.self) { strings in
                    Task { @MainActor in
                        let text = strings.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                        draft += text
                        panel = .none
                        inputFocused.wrappedValue = true
                    }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .controlSize(.large)
                .tint(Color.brand)
                .frame(width: 60, height: 60)
                Text("粘贴").font(.system(size: 12)).foregroundStyle(.secondary)
            }

            if editMode {
                Button(action: onSimulate) { tile("ellipsis.bubble", "模拟回复") }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(height: editMode ? 330 : 240, alignment: .top)
    }

    private func tile(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.primary)
                .frame(width: 60, height: 60)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.inputField))
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

/// 新版微信的选图界面：白底半屏，底部可展开为全屏；选好后点“发送”
struct PhotoSendSheet: View {
    var onSend: ([Data]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [PhotosPickerItem] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            PhotosPicker(selection: $items, maxSelectionCount: 9, selectionBehavior: .ordered, matching: .images) {
                EmptyView()
            }
            .photosPickerStyle(.inline)
            // 去掉系统选图器自带的分段、搜索、添加按钮和底部工具栏，只保留照片网格
            .photosPickerDisabledCapabilities([.selectionActions, .search, .collectionNavigation, .stagingArea])
            .photosPickerAccessoryVisibility(.hidden, edges: .all)
            .navigationTitle("最近项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("photos.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await send() }
                    } label: {
                        Group {
                            if loading { ProgressView().tint(.white) }
                            else { Text(items.isEmpty ? "发送" : "发送(\(items.count))") }
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 6).fill(items.isEmpty ? Color.gray.opacity(0.4) : Color.brand))
                    }
                    .disabled(items.isEmpty || loading)
                    .accessibilityIdentifier("photos.send")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func send() async {
        loading = true
        var images: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let jpeg = ImageUtil.downsampledJPEG(data) {
                images.append(jpeg)
            }
        }
        loading = false
        onSend(images)
        dismiss()
    }
}
