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

    @State private var photoItems: [PhotosPickerItem] = []

    private static let emojis = "😀😁😂🤣😊😍😘😎🤔😅😭😡👍👎👏🙏💪🤝🎉❤️💔🌹☕️🍺🎂🔥✨😴🤗😳😱🙄😏😬🤐😷🤒😇🥳🥺😤👌✌️🙈🌙☀️🍉🐶🐱".map(String.init)

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if editMode { senderSwitch }
            HStack(alignment: .bottom, spacing: 8) {
                barIcon("mic.circle") {}
                TextField("", text: $draft, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(1...5)
                    .focused(inputFocused)
                    .submitLabel(.send)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.inputField))
                    .onChange(of: draft) { _, newValue in
                        // 回车 = 发送
                        if newValue.hasSuffix("\n") {
                            draft.removeLast()
                            onSend()
                        }
                    }
                barIcon(panel == .emoji ? "keyboard" : "face.smiling") { toggle(.emoji) }
                if draft.isEmpty {
                    barIcon("plus.circle") { toggle(.more) }
                } else {
                    Button("发送", action: onSend)
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
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [Data] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let jpeg = ImageUtil.downsampledJPEG(data) {
                        images.append(jpeg)
                    }
                }
                onImages(images)
                photoItems = []
                withAnimation { panel = .none }
            }
        }
    }

    private var senderSwitch: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.circle.fill").foregroundStyle(.orange)
            Text("编辑模式 · 以此身份发送")
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

    private func barIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 27, weight: .light))
                .foregroundStyle(.primary)
                .frame(height: 37)
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
            PhotosPicker(selection: $photoItems, maxSelectionCount: 9, matching: .images) {
                tile("photo", "相册")
            }
            .buttonStyle(.plain)

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
        .frame(height: 230, alignment: .top)
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
