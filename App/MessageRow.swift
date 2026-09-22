import SwiftUI

struct MessageRow: View {
    let message: Message
    let me: Contact?
    let peer: Contact?
    let editMode: Bool
    var onEdit: () -> Void
    var onCopy: () -> Void
    var onRecall: () -> Void
    var onDelete: () -> Void
    var onToggleSender: () -> Void
    var onTapImage: (UIImage) -> Void

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
            HStack(alignment: .top, spacing: 8) {
                if message.fromMe {
                    Spacer(minLength: 56)
                    bubble
                    AvatarView(contact: me, size: 40)
                } else {
                    AvatarView(contact: peer, size: 40)
                    bubble
                    Spacer(minLength: 56)
                }
            }
            .padding(.vertical, 7)
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
        default:
            textBubble
                .onTapGesture { if editMode { onEdit() } }
                .contextMenu { menu }
        }
    }

    private var textBubble: some View {
        Text(message.text)
            .font(.system(size: 17))
            .foregroundStyle(message.fromMe ? Color.textOnMe : Color.textOnOther)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10)
            .padding(.leading, message.fromMe ? 12 : 12 + BubbleShape.arrowWidth)
            .padding(.trailing, message.fromMe ? 12 + BubbleShape.arrowWidth : 12)
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
        Button("编辑", systemImage: "pencil", action: onEdit)
        Button(message.fromMe ? "改为对方发送" : "改为我发送", systemImage: "arrow.left.arrow.right", action: onToggleSender)
        Button("撤回", systemImage: "arrow.uturn.backward", action: onRecall)
        Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
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
