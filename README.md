# WeChat · 本地仿真项目

原项目名 QingLiao；桌面名称保持“WeChat”以兼容 SideStore，应用内首页和底部标签为“微信”，保留微信图标。当前版本 1.1.0（构建 3）重做四个主页和主要聊天交互。原生 SwiftUI + SwiftData，最低 iOS 17，本地运行，不需要服务器或登录。

这是独立的演示应用，不连接腾讯微信服务。“我 → 设置”可查看功能范围。使用独立应用标识，可以与官方微信同时安装，数据各自独立。

## 只有 Windows

看 [Windows 安装到 iPhone 的完整步骤](docs/安装到iPhone.md)。

流程：把源码放进自己的 GitHub 私有仓库 → 手动运行 Build iPhone IPA → 下载 IPA → 用 Windows 的 AltServer / iPhone 的 AltStore Classic 签名安装。无需购买 Mac。

- `.github/workflows/build-ios.yml`：macOS 云端构建，不需要 Apple 账号或证书 Secrets。
- `scripts/build-ipa.sh`：生成 `build/WeChat-Simulator-unsigned.ipa`。
- `project-personal.yml`：个人安装版，不含 App Groups 和分享扩展，支持文字粘贴与相册选图。
- `project.yml`：包含系统分享扩展的完整配置，需要对应签名能力。

打开 [构建与 IPA 下载](https://github.com/Siper99/wechat-local-demo/actions/workflows/build-ios.yml)，选择最新成功构建，在 Artifacts 下载 `WeChat-Simulator-unsigned`。解压后用 SideStore 或 AltStore Classic 签名安装。新版应显示 `WeChat`、版本 `1.1.0`；旧中文名称安装包会触发部分 SideStore 版本的 `appIdName` 错误。尚未完成真机签名安装验证。

## 仿真功能

| 模块 | 当前状态 |
|---|---|
| 聊天列表 | 搜索联系人和消息、草稿恢复、置顶、免打扰、未读、删除、标为未读 |
| 聊天 | 文字、相册和相机发图、看大图、双击文字全文、表情、时间分隔 |
| 编辑模式 | 在“我 → 设置”开启，切换双方身份，改内容、时间和发送方，模拟延迟回复 |
| 消息菜单 | 复制、转发、引用、收藏、多选删除、撤回；编辑模式另有修改消息和发送方 |
| 联系人 | 新建、编辑、删除、头像昵称、发起聊天 |
| 本人资料 | 点“我”页面的头像资料区编辑 |
| 导入 | 个人版支持粘贴和相册；完整版另有系统分享扩展 |
| 发现、服务等入口 | 主要是展示，朋友圈、支付、语音与视频通话尚未实现 |

首次启动有示例联系人和聊天。没有真实联网消息、推送或官方微信聊天记录同步。

## 有 Mac 时直接安装

1. 安装支持手机当前 iOS 的 Xcode（源码最低要求 Xcode 15）和 XcodeGen：`brew install xcodegen`。
2. 在项目目录执行 `xcodegen generate --spec project-personal.yml`。
3. 打开 `QingLiaoPersonal.xcodeproj`，在 QingLiao target 的 Signing & Capabilities 选择自己的 Team，将 Bundle Identifier 改成独一无二的值。
4. 连接 iPhone、信任电脑、开启开发者模式，选择 QingLiao scheme 和真机，点击 Run。

分享扩展版：在 `project.yml` 修改 `QINGLIAO_BUNDLE_ID` 和 `DEVELOPMENT_TEAM`，执行 `xcodegen generate --spec project.yml`，打开 `QingLiao.xcodeproj`。为两个 target 配置同一个 App Group（默认 `group.<你的 QINGLIAO_BUNDLE_ID>`）。运行时从 Info.plist 读取 App Group，无需另外修改 Swift 源码。

个人版与完整版使用不同 Bundle ID 和存储位置，切换版本不会自动迁移聊天记录。日常续签沿用同一账号和标识；卸载应用会删除本地数据。

图标来源见 `App/Assets.xcassets/AppIcon.appiconset/source.txt`。名称与图标用于所请求的本地仿真原型，公开分发前需换成自有品牌并按平台规则处理。

## 界面参考与验证

参考用户指定的 [SwiftUI-WeChat](https://github.com/wxxsw/SwiftUI-WeChat) 和 [WeChatSwift](https://github.com/alexiscn/WeChatSwift)。复用前者的主要页面与输入栏图标，并参考后者会话行的尺寸。开源许可和资源归属见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，应用内“设置 → 开源许可”也可查看。

当前是本地仿真实现，未声称完整复刻官方全部功能。发现页的外部服务入口、真实支付、群聊、语音和视频通话未实现，点击未接入入口会有说明。

云端工作流同时运行 `UITests/ChatFlowTests.swift`，导出主要页面和聊天流程截图到 `iPhone-UI-verification` Artifact。验证结果见每次工作流及 `docs/design-qa.md`。Windows 本地只能检查源码和资源，原生运行与截图由云端 iPhone 模拟器完成。

从 1.0.1 更新时，Bundle ID 保持不变，新增引用、收藏和草稿字段均有默认值。请用同一 SideStore 账号覆盖安装以保留聊天；无需卸载重装。
