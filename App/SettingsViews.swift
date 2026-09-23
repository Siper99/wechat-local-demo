import SwiftUI
import SwiftData
import PhotosUI

/// 我 → 设置（按微信设置页结构）
struct WeChatSettingsView: View {
    @State private var notice: String?

    var body: some View {
        List {
            Section {
                NavigationLink("账号与安全") { AccountSecurityView() }
            }
            Section {
                NavigationLink("消息通知") { NotificationSettingsView() }
                NavigationLink("聊天") { ChatSettingsView() }
                    .accessibilityIdentifier("settings.chat")
                NavigationLink("通用") { GeneralSettingsView() }
            }
            Section {
                NavigationLink("隐私") { PrivacySettingsView() }
            }
            Section {
                NavigationLink("关于本应用") { AboutAppView() }
                NavigationLink("帮助与反馈") {
                    UnavailableFeatureView(title: "帮助与反馈", symbol: "questionmark.circle",
                                           message: "本地演示没有在线客服。功能说明见\u{201C}关于本应用\u{201D}。")
                }
            }
            Section {
                NavigationLink { SimulationSettingsView() } label: {
                    Label("仿真与导入", systemImage: "wand.and.stars")
                }
                .accessibilityIdentifier("settings.simulation")
            }
            Section {
                Button("切换账号") { notice = "切换账号" }.frame(maxWidth: .infinity)
            }
            Section {
                Button("退出") { notice = "退出" }.frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.primary)
        .listStyle(.grouped)
        .navigationTitle("设置")
        .weChatNavigation()
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("知道了", role: .cancel) {}
        } message: { Text("本地演示没有账号系统，无需登录或退出。数据只保存在本机。") }
    }
}

struct AccountSecurityView: View {
    @Query(filter: #Predicate<Contact> { $0.isMe == true }) private var meList: [Contact]
    @State private var editing = false

    var body: some View {
        List {
            Section {
                LabeledContent("微信号", value: meList.first?.handle ?? "wxid_me")
                Button("修改头像和昵称") { editing = true }.foregroundStyle(.primary)
            }
            Section {
                NavigationLink("微信密码") { UnavailableFeatureView(title: "微信密码", symbol: "lock", message: "本地演示没有账号密码。") }
                NavigationLink("声音锁") { UnavailableFeatureView(title: "声音锁", symbol: "waveform", message: "本地演示没有账号登录。") }
                NavigationLink("登录设备管理") { UnavailableFeatureView(title: "登录设备管理", symbol: "desktopcomputer", message: "\u{201C}Windows 微信已登录\u{201D}提示可在\u{201C}仿真与导入\u{201D}中设置。") }
            }
        }
        .listStyle(.grouped)
        .navigationTitle("账号与安全")
        .weChatNavigation()
        .sheet(isPresented: $editing) { if let me = meList.first { ContactEditView(contact: me) } }
    }
}

struct NotificationSettingsView: View {
    @AppStorage("notifyNewMessage") private var newMessage = true
    @AppStorage("notifyShowDetail") private var showDetail = true
    @AppStorage("notifySound") private var sound = true
    @AppStorage("notifyVibrate") private var vibrate = true

    var body: some View {
        List {
            Section {
                Toggle("新消息通知", isOn: $newMessage)
            } footer: {
                Text("模拟回复在 App 退到后台时到达，会发送系统通知。")
            }
            if newMessage {
                Section {
                    Toggle("通知显示消息详情", isOn: $showDetail)
                    Toggle("声音", isOn: $sound)
                    Toggle("振动", isOn: $vibrate)
                }
            }
        }
        .tint(Color.brand)
        .listStyle(.grouped)
        .navigationTitle("消息通知")
        .weChatNavigation()
        .onChange(of: newMessage) { _, on in if on { LocalNotifier.requestAuthorization() } }
        .onAppear { if newMessage { LocalNotifier.requestAuthorization() } }
    }
}

struct ChatSettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("chatBackgroundVersion") private var backgroundVersion = 0
    @AppStorage("voiceUseEarpiece") private var earpiece = false
    @State private var item: PhotosPickerItem?
    @State private var confirmClear = false
    @State private var toast: String?

    private var hasBackground: Bool {
        _ = backgroundVersion
        return FileManager.default.fileExists(atPath: LocalFiles.chatBackground.path())
    }

    var body: some View {
        List {
            Section {
                PhotosPicker(selection: $item, matching: .images) {
                    HStack {
                        Text("聊天背景").foregroundStyle(.primary)
                        Spacer()
                        Text(hasBackground ? "已设置" : "默认").foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settings.chatBackground")
                if hasBackground {
                    Button("恢复默认背景") {
                        try? FileManager.default.removeItem(at: LocalFiles.chatBackground)
                        backgroundVersion += 1
                    }
                }
            }
            Section {
                Toggle("使用听筒播放语音", isOn: $earpiece).tint(Color.brand)
            }
            Section {
                Button("清空全部聊天记录", role: .destructive) { confirmClear = true }
            }
        }
        .listStyle(.grouped)
        .navigationTitle("聊天")
        .weChatNavigation()
        .onChange(of: item) { _, picked in
            guard let picked else { return }
            Task {
                if let raw = try? await picked.loadTransferable(type: Data.self),
                   let jpeg = ImageUtil.downsampledJPEG(raw, maxPixel: 1600) {
                    try? jpeg.write(to: LocalFiles.chatBackground, options: .atomic)
                    backgroundVersion += 1
                }
                item = nil
            }
        }
        .confirmationDialog("将删除所有聊天的消息，联系人和会话保留", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                (try? context.fetch(FetchDescriptor<Message>()))?.forEach { context.delete($0) }
                try? context.save()
            }
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("appearance") private var appearance = 0
    @Query private var messages: [Message]
    @Query private var contacts: [Contact]
    @Query private var moments: [Moment]

    var body: some View {
        List {
            Section {
                Picker("深色模式", selection: $appearance) {
                    Text("跟随系统").tag(0)
                    Text("普通模式").tag(1)
                    Text("深色模式").tag(2)
                }
                .accessibilityIdentifier("settings.appearance")
                NavigationLink("多语言") {
                    UnavailableFeatureView(title: "多语言", symbol: "globe", message: "本地演示仅提供简体中文界面。")
                }
            }
            Section("存储空间") {
                LabeledContent("聊天消息", value: "\(messages.count) 条")
                LabeledContent("联系人", value: "\(contacts.filter { !$0.isMe }.count) 位")
                LabeledContent("朋友圈", value: "\(moments.count) 条")
                Button("清理图片缓存") {
                    VideoThumbnailCache.cache.removeAllObjects()
                }
            }
        }
        .listStyle(.grouped)
        .navigationTitle("通用")
        .weChatNavigation()
    }
}

struct PrivacySettingsView: View {
    @AppStorage("privacyVerify") private var verify = true
    @AppStorage("privacySearchByID") private var searchByID = true
    @AppStorage("privacyMomentsRange") private var momentsRange = "全部"
    @AppStorage("privacyStrangerMoments") private var strangers = false

    var body: some View {
        List {
            Section("添加我的方式") {
                Toggle("加我为朋友时需要验证", isOn: $verify)
                Toggle("可通过微信号搜索到我", isOn: $searchByID)
            }
            Section("朋友圈") {
                Picker("允许朋友查看朋友圈的范围", selection: $momentsRange) {
                    ForEach(["全部", "最近半年", "最近一个月", "最近三天"], id: \.self) { Text($0) }
                }
                Toggle("允许陌生人查看十条朋友圈", isOn: $strangers)
            }
            Section {
            } footer: {
                Text("本地演示只有本机数据，这些选项仅保存偏好。")
            }
        }
        .tint(Color.brand)
        .listStyle(.grouped)
        .navigationTitle("隐私")
        .weChatNavigation()
    }
}

struct AboutAppView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.brand)
                    Text("WeChat 本地仿真").font(.system(size: 18, weight: .semibold))
                    Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            Section {
                Text("用于本地演示，不是腾讯官方微信，不连接微信账号或服务器。聊天、朋友圈、收藏等数据只保存在本机。")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
                NavigationLink("开源许可") { OpenSourceNoticesView() }
            }
        }
        .listStyle(.grouped)
        .navigationTitle("关于本应用")
        .weChatNavigation()
    }
}
