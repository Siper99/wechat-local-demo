import SwiftUI

struct SimulationSettingsView: View {
    @AppStorage("editMode") private var editMode = false

    var body: some View {
        List {
            Section("聊天仿真") {
                Toggle("编辑模式", isOn: $editMode)
                    .tint(Color.brand)
                Text("开启后可切换双方身份发送消息，点击消息修改内容、时间和发送方，也可以在 ＋ 面板安排延迟回复。关闭后恢复普通聊天展示。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("关于本应用") {
                LabeledContent("类型", value: "本地聊天仿真")
                LabeledContent("版本", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                LabeledContent("安装配置", value: AppGroup.id == nil ? "个人版" : "分享扩展版")
                Text("用于本地演示，不是腾讯官方微信，不连接微信账号或服务器。对话与人物均可自行编辑，消息保存在本机。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("当前功能范围") {
                Text("已实现：文字和图片聊天、联系人、头像昵称、消息编辑、延迟回复、未读和置顶。")
                Text("朋友圈、视频号、服务等入口目前为界面展示；语音、视频通话、支付和联网聊天尚未实现。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
