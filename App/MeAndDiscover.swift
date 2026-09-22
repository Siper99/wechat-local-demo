import SwiftUI
import SwiftData

struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            List {
                Section { IconRow(icon: "camera.aperture", color: .orange, title: "朋友圈") }
                Section {
                    IconRow(icon: "play.rectangle.fill", color: .orange, title: "视频号")
                    IconRow(icon: "dot.radiowaves.left.and.right", color: .pink, title: "直播")
                }
                Section {
                    IconRow(icon: "qrcode.viewfinder", color: .blue, title: "扫一扫")
                    IconRow(icon: "iphone.radiowaves.left.and.right", color: .blue, title: "摇一摇")
                }
                Section {
                    IconRow(icon: "sparkles", color: .yellow, title: "看一看")
                    IconRow(icon: "magnifyingglass", color: .red, title: "搜一搜")
                }
                Section { IconRow(icon: "location.fill", color: .blue, title: "附近") }
                Section {
                    IconRow(icon: "bag.fill", color: .orange, title: "购物")
                    IconRow(icon: "gamecontroller.fill", color: .purple, title: "游戏")
                }
                Section { IconRow(icon: "square.grid.2x2.fill", color: .purple, title: "小程序") }
            }
            .navigationTitle("发现")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MeView: View {
    @Query(filter: #Predicate<Contact> { $0.isMe == true }) private var meList: [Contact]
    @AppStorage("editMode") private var editMode = false
    @State private var showProfile = false

    private var me: Contact? { meList.first }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showProfile = true } label: {
                        HStack(spacing: 16) {
                            AvatarView(contact: me, size: 64)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(me?.name ?? "我")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("微信号：\(me?.handle ?? "wxid_me")")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "qrcode").foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 14)
                    }
                }
                Section { IconRow(icon: "checkmark.shield.fill", color: Color.brand, title: "服务") }
                Section {
                    IconRow(icon: "cube.fill", color: .orange, title: "收藏")
                    IconRow(icon: "photo.on.rectangle", color: .blue, title: "朋友圈")
                    IconRow(icon: "face.smiling.inverse", color: .yellow, title: "表情")
                }
                Section {
                    Toggle(isOn: $editMode) {
                        IconRow(icon: "pencil", color: .orange, title: "编辑模式")
                    }
                    .tint(Color.brand)
                } footer: {
                    Text("开启后，聊天里可以切换用\u{201C}对方\u{201D}身份发送、点消息直接改内容和时间、在 ＋ 面板里模拟对方回复。")
                }
                Section {
                    NavigationLink { ImportGuideView() } label: {
                        IconRow(icon: "square.and.arrow.down.fill", color: Color.brand, title: "如何导入消息")
                    }
                    NavigationLink { SimulationSettingsView() } label: {
                        IconRow(icon: "gearshape.fill", color: .blue, title: "设置")
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfile) {
                if let me { ContactEditView(contact: me) }
            }
        }
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
