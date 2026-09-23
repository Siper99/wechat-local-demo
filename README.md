# WeChat · 本地仿真项目

原项目名 QingLiao；桌面名称保持“WeChat”以兼容 SideStore，应用内首页和底部标签为“微信”，保留微信图标。当前版本 1.4.2（构建 8）：按实机截图重绘 ＋ 菜单、通讯录、发现和“我”页的图标；在实机截图和 2026 年新版微信界面的基础上，为"我""发现""通讯录"的每个入口加上本地可用的基础功能，并支持群聊、语音消息、名片和模拟音视频通话。原生 SwiftUI + SwiftData，最低 iOS 17，本地运行，不需要服务器或登录。

这是独立的演示应用，不连接腾讯微信服务。“我 → 设置”可查看功能范围。使用独立应用标识，可以与官方微信同时安装，数据各自独立。

## 只有 Windows

看 [Windows 安装到 iPhone 的完整步骤](docs/安装到iPhone.md)。

流程：把源码放进自己的 GitHub 私有仓库 → 手动运行 Build iPhone IPA → 下载 IPA → 用 Windows 的 AltServer / iPhone 的 AltStore Classic 签名安装。无需购买 Mac。

- `.github/workflows/build-ios.yml`：macOS 云端构建，不需要 Apple 账号或证书 Secrets。
- `scripts/build-ipa.sh`：生成 `build/WeChat-Simulator-unsigned.ipa`。
- `project-personal.yml`：个人安装版，不含 App Groups 和分享扩展，支持文字粘贴与相册选图。
- `project.yml`：包含系统分享扩展的完整配置，需要对应签名能力。

打开 [构建与 IPA 下载](https://github.com/Siper99/wechat-local-demo/actions/workflows/build-ios.yml)，选择最新成功构建，在 Artifacts 下载 `WeChat-Simulator-unsigned`。解压后用 SideStore 或 AltStore Classic 签名安装。新版应显示 `WeChat`、版本 `1.4.2`；旧中文名称安装包会触发部分 SideStore 版本的 `appIdName` 错误。尚未完成真机签名安装验证。

## 仿真功能

| 模块 | 当前状态 |
|---|---|
| 聊天列表 | 搜索、草稿、置顶、免打扰、未读；左滑圆角“标为未读 / 删除”；群聊九宫格头像 |
| 聊天 | 文字、图片、表情与收藏表情、语音消息（按住说话、上滑取消）、位置、名片、模拟音视频通话、引用、转发、收藏、撤回、多选删除 |
| 群聊 | 发起群聊、成员昵称、添加成员、修改群名、退出群聊；编辑模式可选择由哪位成员发言 |
| 我 → 服务 | 各服务入口可打开；钱包 → 零钱显示本地演示金额（可演示充值/提现，始终标注“演示”）；收付款、转账、收款码不提供 |
| 我 → 收藏 | 聊天收藏 + 笔记，按类型筛选、搜索、删除 |
| 朋友圈 | 发表文字和最多 9 张图、位置、点赞、评论和回复、删除、更换封面；好友朋友圈；“仅聊天”好友不显示 |
| 作品 / 视频号 | 从相册导入视频，竖向翻页播放、点赞 |
| 小店与卡包 | 会员卡、优惠券、票券（仅名称和备注） |
| 表情 | 从相册添加、整理删除；聊天中长按图片可“添加到表情” |
| 设置 | 账号与安全、消息通知（后台模拟回复发通知）、聊天背景、清空聊天记录、深色模式、隐私偏好、仿真与导入 |
| 发现 | 直播（前置相机本机预览）、扫一扫（相机或相册识别二维码）、听一听（导入本地音乐播放）、看一看（公众号文章、在看）、搜一搜（本机全局搜索 + 网页搜索）、附近的人（地图显示自己位置）、游戏（2048）、小程序（计算器、记事本、自定义网页） |
| 通讯录 | 新的朋友（接受申请）、仅聊天的朋友、群聊、标签、公众号 / 服务号文章、好友资料（备注和标签、朋友权限、朋友圈、音视频通话） |

红包、转账、收付款刻意不做成可用功能（零钱只显示带“演示”标注的本地金额），以免生成的界面被误当作真实支付凭证。联网账号、真实通话、企业微信等需要服务器的功能只保留说明页。

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

从 1.0.1 / 1.1.0 更新时，Bundle ID 保持不变，新增字段（引用、收藏、草稿、位置、内置会话标记）均有默认值。请用同一 SideStore 账号覆盖安装以保留聊天；无需卸载重装。升级后会补充“文件传输助手”联系人，可在 ＋ → 发起群聊中选择，不会向已有聊天插入消息。
