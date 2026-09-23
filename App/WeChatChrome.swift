import SwiftUI

enum MainTab: Int, CaseIterable {
    case chats, contacts, discover, me
    var title: String { ["微信", "通讯录", "发现", "我"][rawValue] }
    var symbol: String { ["message", "person.text.rectangle", "safari", "person"][rawValue] }
    var selectedSymbol: String { ["message.fill", "person.text.rectangle.fill", "safari.fill", "person.fill"][rawValue] }
    var asset: String { ["root_tab_chat", "root_tab_contact", "root_tab_discover", "root_tab_me"][rawValue] }
}

struct WeChatTabBar: View {
    @Binding var selection: MainTab
    let unread: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.rawValue) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 3) {
                        Image(tab.asset + (selection == tab ? "_selected" : ""))
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 28, height: 26)
                            .overlay(alignment: .topTrailing) {
                                if tab == .chats && unread > 0 {
                                    Text(unread > 99 ? "99+" : "\(unread)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Capsule().fill(Color.red))
                                        .fixedSize()
                                        .offset(x: 12, y: -4)
                                }
                            }
                        Text(tab.title).font(.system(size: 10))
                    }
                    .foregroundStyle(selection == tab ? Color.brand : Color.tabInactive)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(tab.rawValue)")
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.top, 4)
        .background(Color.inputBar.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5) }
    }
}

struct WeChatSearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if focused || !text.isEmpty {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                }
                TextField("", text: $text)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .accessibilityLabel("搜索")
                    .accessibilityIdentifier("search.field")
                    .testingKeyboard()
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }.accessibilityLabel("清除搜索")
                }
            }
            .font(.system(size: 16))
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color.inputField, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                if !focused && text.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass")
                        Text("搜索")
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
                }
            }
            if focused {
                Button("取消") { text = ""; focused = false }
                    .font(.system(size: 16))
                    .foregroundStyle(Color.linkBlue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.chatBackground)
    }
}

struct WeChatRow: View {
    let title: String
    var icon: String? = nil
    var color: Color = .primary
    var detail: String? = nil
    var chevron = true
    var asset: String? = nil
    /// 不显示左侧图标（如好友资料页）
    var plain = false

    private var resource: String? {
        if plain { return nil }
        return asset ?? ["朋友圈": "wc_moments", "视频号": "wc_channels", "直播": "wc_live",
                  "扫一扫": "wc_scan", "听一听": "wc_listen", "看一看": "wc_look", "搜一搜": "wc_search",
                  "附近的人": "wc_nearby", "游戏": "wc_game", "小程序": "discover_miniprogram",
                  "服务": "me_pay", "收藏": "wc_favorites", "作品": "wc_works", "小店与卡包": "wc_shop",
                  "表情": "wc_emoji", "设置": "me_setting"][title]
    }

    var body: some View {
        HStack(spacing: 16) {
            if plain {
                EmptyView()
            } else if let resource {
                Image(resource).resizable().scaledToFit().frame(width: 24, height: 24)
                    .frame(width: 24, height: 26)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(color)
                    .frame(width: 24)
            }
            Text(title).font(.system(size: 17)).foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let detail { Text(detail).font(.system(size: 14)).foregroundStyle(Color.wcSecondary) }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.wcTips)
                    .frame(width: 12, height: 24)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(Color.cellBackground)
        .contentShape(Rectangle())
    }
}

struct WeChatGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color.cellBackground)
    }
}

struct WeChatSeparator: View {
    var leading: CGFloat = 56
    var body: some View { Divider().padding(.leading, leading) }
}

extension Color {
    static let linkBlue = Color(UIColor(hex: 0x576B95))
    /// 底部标签未选中：浅色 #181818，深色 90% 白
    static let tabInactive = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 1, alpha: 0.9) : UIColor(red: 0x18 / 255, green: 0x18 / 255, blue: 0x18 / 255, alpha: 1) })
}

extension View {
    /// 导航栏外观由 WeChatAppearance 统一设置（灰底、无底部分隔线）
    func weChatNavigation() -> some View {
        self.navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
    }
}

enum WeChatAppearance {
    static func apply() {
        let background = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x111111) : UIColor(hex: 0xEDEDED) }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        // 与微信一致：返回按钮只显示箭头，不显示上一页标题
        let hidden: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.clear]
        appearance.backButtonAppearance.normal.titleTextAttributes = hidden
        appearance.backButtonAppearance.highlighted.titleTextAttributes = hidden
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
    }
}

/// 隐藏系统返回按钮后仍保留边缘右滑返回
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

/// 聊天页左上角：返回箭头 + 其他会话未读数（灰色圆角）
struct WeChatBackButton: View {
    let unread: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                if unread > 0 {
                    Text(unread > 99 ? "99+" : "\(unread)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 7)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Capsule().fill(Color.dynamic(0xD6D6D6, 0x3A3A3A)))
                }
            }
            .foregroundStyle(.primary)
        }
        .accessibilityLabel(unread > 0 ? "返回，\(unread) 条未读" : "返回")
        .accessibilityIdentifier("nav.back")
    }
}

// MARK: - 左滑操作（新版微信：圆角按钮，删除需二次确认）

struct SwipeAction {
    let title: String
    let color: Color
    var confirmTitle: String? = nil
    let action: () -> Void
}

struct SwipeActionRow<Content: View>: View {
    let id: UUID
    @Binding var openID: UUID?
    let actions: [SwipeAction]
    /// 点按行（已展开时改为收起）；拖动过程中及刚结束时的点按会被忽略
    var onTap: () -> Void = {}
    @ViewBuilder var content: Content

    @State private var drag: CGFloat = 0
    @State private var confirming: Int?
    @State private var dragging = false
    @State private var lastDragEnd = Date.distantPast

    private static var buttonWidth: CGFloat { 76 }
    private static var gap: CGFloat { 6 }
    private var revealWidth: CGFloat { CGFloat(actions.count) * (Self.buttonWidth + Self.gap) + Self.gap }
    private var isOpen: Bool { openID == id }
    private var baseOffset: CGFloat { isOpen ? -revealWidth : 0 }
    private var offset: CGFloat { baseOffset + drag }

    var body: some View {
        content
            .onTapGesture {
                guard !dragging, Date().timeIntervalSince(lastDragEnd) > 0.35 else { return }
                if openID != nil { withAnimation(.snappy(duration: 0.25)) { openID = nil } }
                else { onTap() }
            }
            .offset(x: offset)
            .background(alignment: .trailing) { if offset < -1 { buttons } }
            .clipped()
            .modifier(HorizontalSwipe(allowRight: isOpen, onChanged: changed, onEnded: ended))
            .onChange(of: openID) { _, _ in if !isOpen { confirming = nil } }
    }

    private func changed(_ translation: CGFloat) {
        dragging = true
        let target = min(max(baseOffset + translation, -revealWidth - 30), 0)
        drag = target - baseOffset
    }

    private func ended(_ translation: CGFloat, _ velocity: CGFloat) {
        dragging = false
        lastDragEnd = Date()
        guard drag != 0 else { return }
        let final = baseOffset + drag + velocity * 0.1
        withAnimation(.snappy(duration: 0.25)) {
            if final < -revealWidth / 2 { openID = id } else if isOpen { openID = nil }
            drag = 0
            confirming = nil
        }
    }

    private var buttons: some View {
        HStack(spacing: Self.gap) {
            ForEach(actions.indices, id: \.self) { index in
                if confirming == nil || confirming == index {
                    let item = actions[index]
                    Button {
                        if let _ = item.confirmTitle, confirming != index {
                            withAnimation(.snappy(duration: 0.2)) { confirming = index }
                        } else {
                            withAnimation(.snappy(duration: 0.25)) { openID = nil }
                            confirming = nil
                            item.action()
                        }
                    } label: {
                        Text(confirming == index ? (item.confirmTitle ?? item.title) : item.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(item.color))
                    }
                    .buttonStyle(.plain)
                    .frame(width: confirming == index ? revealWidth - Self.gap * 2 : Self.buttonWidth)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, Self.gap)
        .frame(width: revealWidth, alignment: .trailing)
    }
}

/// 横向拖动：iOS 18 起用 UIKit 手势（只在横向时开始，并让滚动视图等待它失败），
/// 避免 ScrollView 抢走拖动；iOS 17 使用 SwiftUI DragGesture。
private struct HorizontalSwipe: ViewModifier {
    var allowRight: Bool
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat, CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(HorizontalPanGesture(allowRight: allowRight, onChanged: onChanged, onEnded: onEnded))
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 14)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                        onChanged(value.translation.width)
                    }
                    .onEnded { value in
                        onEnded(value.translation.width, value.velocity.width)
                    }
            )
        }
    }
}

@available(iOS 18.0, *)
private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    var allowRight: Bool
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.allowRight = allowRight
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began, .changed:
            onChanged(translation)
        case .ended, .cancelled, .failed:
            onEnded(translation, recognizer.velocity(in: recognizer.view).x)
        default:
            break
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var allowRight = false

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            guard abs(velocity.x) > abs(velocity.y) * 1.2 else { return false }
            return velocity.x < 0 || allowRight
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer.view is UIScrollView
        }
    }
}
