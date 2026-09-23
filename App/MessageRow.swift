import SwiftUI

struct MessageRow: View {
    let message: Message
    let me: Contact?
    let peer: Contact?
    /// 群聊中显示在气泡上方的对方昵称
    var senderName: String? = nil
    var cardContact: Contact? = nil
    let editMode: Bool
    var onEdit: () -> Void
    var onCopy: () -> Void
    var onRecall: () -> Void
    var onDelete: () -> Void
    var onToggleSender: () -> Void
    var onTapImage: (UIImage) -> Void
    var onForward: () -> Void
    var onQuote: () -> Void
    var onFavorite: () -> Void
    var onSelect: () -> Void
    var onTapCard: (Contact) -> Void = { _ in }
    var onAddSticker: () -> Void = {}
    @State private var showFullText = false

    var body: some View {
        if message.kind == .system {
            Text(message.text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { if editMode { onEdit() } }
                .contextMenu {
                    Button("编辑", systemImage: "pencil", action: onEdit)
                    Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
                }
        } else {
            HStack(alignment: .top, spacing: 6) {
                if message.fromMe {
                    Spacer(minLength: 56)
                    bubble
                    AvatarView(contact: me, size: 40)
                } else {
                    AvatarView(name: peer?.name ?? senderName ?? "?", data: peer?.avatarData, size: 40)
                    if let senderName {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(senderName).font(.system(size: 12)).foregroundStyle(.secondary)
                                .padding(.leading, BubbleShape.arrowWidth + 2)
                            bubble
                        }
                    } else {
                        bubble
                    }
                    Spacer(minLength: 56)
                }
            }
            .padding(.vertical, 7)
            .fullScreenCover(isPresented: $showFullText) {
                FullTextView(text: message.text)
            }
        }
    }

    @ViewBuilder private var bubble: some View {
        switch message.kind {
        case .image:
            imageBubble
                .onTapGesture {
                    if editMode {
                        onEdit()
                    } else if let image = ImageCache.image(for: message.id, data: message.imageData) {
                        onTapImage(image)
                    }
                }
                .contextMenu { menu }
        case .voice:
            VoiceBubble(message: message)
                .onTapGesture { if editMode { onEdit() } else { VoicePlayer.shared.toggle(message) } }
                .contextMenu { menu }
        case .card:
            CardBubble(message: message, contact: cardContact)
                .onTapGesture {
                    if editMode { onEdit() } else if let cardContact { onTapCard(cardContact) }
                }
                .contextMenu { menu }
        case .call:
            CallBubble(message: message)
                .onTapGesture { if editMode { onEdit() } }
                .contextMenu { menu }
        case .location:
            LocationBubble(message: message)
                .onTapGesture {
                    if editMode { onEdit() } else { LocationBubble.open(message) }
                }
                .contextMenu { menu }
        default:
            VStack(alignment: message.fromMe ? .trailing : .leading, spacing: 5) {
                textBubble
                    .onTapGesture(count: 2) { showFullText = true }
                    .onTapGesture { if editMode { onEdit() } }
                if let quote = message.quotedText {
                    Text("\(message.quotedSender ?? "联系人")：\(quote)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                        .padding(.horizontal, BubbleShape.arrowWidth)
                }
            }
                .contextMenu { menu }
        }
    }

    private var textBubble: some View {
        Text(message.text)
            .font(.system(size: 17))
            .lineSpacing(3)
            .foregroundStyle(message.fromMe ? Color.textOnMe : Color.textOnOther)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10)
            .padding(.leading, message.fromMe ? 12 : 17)
            .padding(.trailing, message.fromMe ? 15 : 12)
            .frame(minHeight: 40)
            .background(
                BubbleShape(isMe: message.fromMe)
                    .fill(message.fromMe ? Color.bubbleMe : Color.bubbleOther)
            )
            .contentShape(BubbleShape(isMe: message.fromMe))
    }

    @ViewBuilder private var imageBubble: some View {
        if let image = ImageCache.image(for: message.id, data: message.imageData) {
            let size = fittedSize(image.size, maxWidth: 150, maxHeight: 200)
            Image(uiImage: image)
                .resizable()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 120, height: 120)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }

    private func fittedSize(_ size: CGSize, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: maxWidth, height: maxWidth) }
        let scale = min(maxWidth / size.width, maxHeight / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    @ViewBuilder private var menu: some View {
        if message.kind == .text {
            Button("复制", systemImage: "doc.on.doc", action: onCopy)
        }
        if message.kind == .image {
            Button("添加到表情", systemImage: "face.smiling", action: onAddSticker)
        }
        Button("转发", systemImage: "arrowshape.turn.up.right", action: onForward)
        Button(message.isFavorite ? "取消收藏" : "收藏", systemImage: "cube", action: onFavorite)
        Button("引用", systemImage: "quote.bubble", action: onQuote)
        if message.fromMe || editMode {
            Button("撤回", systemImage: "arrow.uturn.backward", action: onRecall)
        }
        Button("多选", systemImage: "checkmark.circle", action: onSelect)
        if editMode {
            Button("编辑", systemImage: "pencil", action: onEdit)
            Button(message.fromMe ? "改为对方发送" : "改为我发送", systemImage: "arrow.left.arrow.right", action: onToggleSender)
        }
        Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
    }
}

struct FullTextView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            Text(text).font(.system(size: 28))
                .frame(maxWidth: .infinity, minHeight: 400, alignment: .center)
                .padding(28)
        }
        .background(Color.cellBackground)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: { Image(systemName: "xmark").padding(20) }
                .accessibilityLabel("关闭全文")
        }
    }
}

/// 带小三角的气泡
struct BubbleShape: Shape {
    static let arrowWidth: CGFloat = 6
    var isMe: Bool

    func path(in rect: CGRect) -> Path {
        let arrowHeight: CGFloat = 12
        let arrowCenterY: CGFloat = 20   // 对齐 40pt 头像的中线
        var body = rect
        body.size.width -= Self.arrowWidth
        if !isMe { body.origin.x += Self.arrowWidth }

        var path = Path(roundedRect: body, cornerRadius: 5, style: .continuous)
        let edgeX = isMe ? body.maxX : body.minX
        let tipX = isMe ? rect.maxX : rect.minX
        path.move(to: CGPoint(x: edgeX, y: arrowCenterY - arrowHeight / 2))
        path.addLine(to: CGPoint(x: tipX, y: arrowCenterY))
        path.addLine(to: CGPoint(x: edgeX, y: arrowCenterY + arrowHeight / 2))
        path.closeSubpath()
        return path
    }
}
