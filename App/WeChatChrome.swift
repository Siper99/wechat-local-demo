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
                    .foregroundStyle(selection == tab ? Color.brand : Color(UIColor(hex: 0x7C8085)))
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
        .padding(.horizontal, 8)
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

    private var resource: String? {
        asset ?? ["朋友圈": "discover_moment", "扫一扫": "discover_qrcode", "看一看": "discover_see",
                  "搜一搜": "discover_search", "附近": "discover_nearby", "购物": "discover_shop",
                  "游戏": "discover_game", "小程序": "discover_miniprogram", "服务": "me_pay",
                  "收藏": "me_favorite", "卡包": "me_bank_card", "表情": "me_emoji", "设置": "me_setting"][title]
    }

    var body: some View {
        HStack(spacing: 12) {
            if let resource {
                Image(resource).resizable().scaledToFit().frame(width: 24, height: 26)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(color)
                    .frame(width: 24)
            }
            Text(title).font(.system(size: 17)).foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let detail { Text(detail).font(.system(size: 14)).foregroundStyle(.secondary) }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}

struct WeChatGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color(.systemBackground))
    }
}

struct WeChatSeparator: View {
    var leading: CGFloat = 52
    var body: some View { Divider().padding(.leading, leading) }
}

extension Color {
    static let linkBlue = Color(UIColor(hex: 0x576B95))
}

extension View {
    func weChatNavigation() -> some View {
        self.navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.chatBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar(.visible, for: .navigationBar)
    }
}
