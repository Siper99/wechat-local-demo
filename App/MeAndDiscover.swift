import SwiftUI
import SwiftData

struct DiscoverView: View {
    @State private var feature: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                WeChatGroup { entry("朋友圈", "camera.aperture", .orange) }
                WeChatGroup {
                    entry("视频号", "play.rectangle", .orange)
                    WeChatSeparator()
                    entry("直播", "dot.radiowaves.left.and.right", .pink)
                }
                WeChatGroup {
                    entry("扫一扫", "qrcode.viewfinder", .blue)
                    WeChatSeparator()
                    entry("听一听", "music.note", .orange)
                }
                WeChatGroup {
                    entry("看一看", "sun.max", .orange)
                    WeChatSeparator()
                    entry("搜一搜", "magnifyingglass", .red)
                }
                WeChatGroup { entry("附近", "location", .blue) }
                WeChatGroup {
                    entry("购物", "bag", .orange)
                    WeChatSeparator()
                    entry("游戏", "gamecontroller", .purple)
                }
                WeChatGroup { entry("小程序", "app.connected.to.app.below.fill", .purple) }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Color.chatBackground)
        .navigationTitle("发现")
        .weChatNavigation()
        .alert(feature ?? "", isPresented: Binding(get: { feature != nil }, set: { if !$0 { feature = nil } })) {
            Button("知道了", role: .cancel) { }
        } message: { Text("当前版本专注本地聊天与联系人，此入口暂未接入服务。") }
    }

    private func entry(_ title: String, _ icon: String, _ color: Color) -> some View {
        Button { feature = title } label: { WeChatRow(title: title, icon: icon, color: color) }
            .buttonStyle(.plain)
    }
}

struct MeView: View {
    @Query(filter: #Predicate<Contact> { $0.isMe == true }) private var meList: [Contact]
    @AppStorage("profileStatus") private var profileStatus = ""
    @State private var showProfile = false
    @State private var showStatus = false
    @State private var feature: String?
    private var me: Contact? { meList.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                profile
                WeChatGroup { entry("服务", "creditcard", .brand) }
                WeChatGroup {
                    NavigationLink { FavoritesView() } label: {
                        WeChatRow(title: "收藏", icon: "cube", color: .orange)
                    }.buttonStyle(.plain).accessibilityIdentifier("me.favorites")
                    WeChatSeparator()
                    entry("朋友圈", "photo", .blue)
                    WeChatSeparator()
                    entry("卡包", "wallet.pass", .blue)
                    WeChatSeparator()
                    entry("表情", "face.smiling", .orange)
                }
                WeChatGroup {
                    NavigationLink { SimulationSettingsView() } label: {
                        WeChatRow(title: "设置", icon: "gearshape", color: .blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("me.settings")
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.chatBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showProfile) { if let me { ContactEditView(contact: me) } }
        .confirmationDialog("设置状态", isPresented: $showStatus, titleVisibility: .visible) {
            ForEach(["忙碌", "工作", "休息", "在线"], id: \.self) { status in
                Button(status) { profileStatus = status }
            }
            Button("清除状态") { profileStatus = "" }
        }
        .alert(feature ?? "", isPresented: Binding(get: { feature != nil }, set: { if !$0 { feature = nil } })) {
            Button("知道了", role: .cancel) { }
        } message: { Text("此入口暂未接入。聊天、联系人和消息收藏可在本机使用。") }
    }

    private var profile: some View {
        HStack(alignment: .top, spacing: 20) {
            Button { showProfile = true } label: { AvatarView(contact: me, size: 64) }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑我的头像")
            VStack(alignment: .leading, spacing: 10) {
                Button { showProfile = true } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(me?.name ?? "我")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(.primary)
                        HStack {
                            Text("微信号：\(me?.handle ?? "wxid_me")")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Image(systemName: "qrcode").font(.system(size: 17))
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain)
                Button { showStatus = true } label: {
                    Label(profileStatus.isEmpty ? "状态" : profileStatus, systemImage: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .overlay(Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 42)
        .padding(.bottom, 36)
        .background(Color(.systemBackground))
    }

    private func entry(_ title: String, _ icon: String, _ color: Color) -> some View {
        Button { feature = title } label: { WeChatRow(title: title, icon: icon, color: color) }
            .buttonStyle(.plain)
    }
}

struct ImportGuideView: View {
    var body: some View {
        List {
            Section("文字消息") {
                step(1, "在来源 App 里长按文字，点\u{201C}复制\u{201D}")
                step(2, "回到本应用，打开要放进去的聊天")
                step(3, "底部会出现\u{201C}剪贴板有新内容\u{201D}，选\u{201C}作为对方 / 作为我\u{201D}，点\u{201C}粘贴\u{201D}")
            }
            Section("图片") {
                step(1, "把需要的图片保存到系统相册")
                step(2, "在本应用的聊天里点 ＋ → 相册，选好图片后添加")
                step(3, "需要模拟对方发图时，先开启编辑模式，把发送方切换为对方")
            }
            if AppGroup.id != nil {
                Section("系统分享导入") {
                    step(1, "在照片、Safari 或备忘录里点分享，选择本应用的分享扩展")
                    step(2, "选择对话、发送方和时间，点插入，再回到本应用")
                    Text("分享扩展标题为“导入到微信（本地仿真）”，可据此和官方应用区分。")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("当前版本") {
                    Text("个人安装版支持文字粘贴和相册选图，没有系统分享扩展。链接可以作为文字复制粘贴。")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("如何导入消息")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.brand))
            Text(text).font(.system(size: 15))
        }
        .padding(.vertical, 2)
    }
}
