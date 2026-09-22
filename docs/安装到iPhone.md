# Windows 安装本地仿真应用到 iPhone

## 推荐方案

GitHub Actions 的 macOS 环境编译，Windows 的 AltServer 和 iPhone 的 AltStore Classic 完成个人签名安装。不需要拥有 Mac，不需要越狱。首次云端构建已成功，IPA 已生成；尚未完成真机签名安装验证。

需要 iOS 17+ 的 iPhone、Windows 电脑、数据线、GitHub 账号和自己的 Apple 账号。

免费账号签名 7 天后过期，需要刷新；同一设备最多安装 3 个此类个人签名应用，AltStore 也占用名额。参见 [Apple Personal Team 说明](https://developer.apple.com/help/account/basics/about-your-developer-account) 和 [AltStore 使用说明](https://faq.altstore.io/altstore-classic/your-altstore)。

## 1. 生成 IPA

本项目已上传到 [私有仓库](https://github.com/Siper99/wechat-local-demo)，并已完成 [首次成功构建](https://github.com/Siper99/wechat-local-demo/actions/runs/35696780434)。你可以直接进入该构建页面下载 Artifacts，再从第 2 节开始。下面保留重新构建步骤。

1. 登录 GitHub，新建一个 **Private 私有仓库**，例如 `wechat-local-demo`。
2. 上传项目内容。仓库根目录应直接出现 `project-personal.yml`、`App`、`Shared`、`scripts` 和 `.github`，不要多套一层 QingLiao 文件夹，也不要只上传 ZIP。
3. 特别确认 `.github/workflows/build-ios.yml` 已上传。可用 GitHub Desktop 创建本地仓库，再 Publish repository，保持私有选项；这比网页上传更容易保留带点目录。
4. 进入仓库 **Actions**，启用 Actions（如提示），选择 **Build iPhone IPA → Run workflow**。
5. 等待绿色成功标记，打开运行详情，下载 **Artifacts → WeChat-Simulator-unsigned**。
6. 解压得到 `WeChat-Simulator-unsigned.ipa`，接下来还需签名，直接点击不能安装。

工作流只编译个人版，不含分享扩展，无需 Apple 密码、证书或 GitHub Secrets。构建产物保留 7 天，到期可重新运行。GitHub 可用构建额度及计费以账号页面为准。

## 2. Windows 安装 AltStore

按 [AltStore 官方 Windows 安装指南](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) 操作：

1. 安装指南要求的 iTunes 和 iCloud，使用指南里的 Apple 下载链接；Microsoft Store 版本可能需额外配置。
2. 从 [AltStore 官网](https://altstore.io/) 下载 Windows 的 AltServer，安装并启动。使用 AltStore Classic。
3. 数据线连接并解锁 iPhone，点“信任此电脑”。确认 iTunes 识别手机，并开启 Wi-Fi 同步。
4. 点击 Windows 托盘的 AltServer，选择 **Install AltStore → 你的 iPhone**，在本机提示中用自己的 Apple 账号签名。
5. 在 iPhone“设置 → 通用 → VPN 与设备管理”信任自己的开发者签名；“设置 → 隐私与安全 → 开发者模式”开启并按提示重启。

Apple 账号用于本机签名，不要填进源码、GitHub 或聊天消息。

## 3. 安装本项目

1. 将 IPA 传到 iPhone“文件”App，例如通过 iCloud Drive。
2. 保持 AltServer 运行，手机连接数据线，或与电脑保持可互通的同一 Wi-Fi。
3. 打开 iPhone 的 AltStore Classic，进入 **My Apps → ＋**，选择 IPA，等待签名安装。
4. 桌面会出现名为“微信”的应用，使用微信图标。建议放进单独文件夹，便于与官方应用区分。
5. 打开“我 → 设置”，应看到“本地聊天仿真 / 个人版”。开启编辑模式，进入聊天即可切换双方身份和编辑消息。

应用有独立 Bundle ID，不替换官方微信，也不会自动获取官方微信账号和聊天数据库。

## 4. 每周续签

到期前运行电脑上的 AltServer，让手机可连接电脑，在 AltStore 的 My Apps 点 **Refresh All**。可以开启后台刷新，但应确认剩余有效期。参见 [AltStore 刷新说明](https://faq.altstore.io/altstore-classic/your-altstore)。

如果已经过期，先恢复 AltStore 签名，再用同一个账号刷新本应用。尽量不要卸载，聊天保存在本机，删除会丢失数据。

## 常见问题

| 情况 | 处理 |
|---|---|
| Actions 没有工作流 | 检查默认分支是否包含 `.github/workflows/build-ios.yml` |
| 构建失败 | 打开失败步骤，保存第一条编译错误及上下文继续修复；失败构建没有可安装 IPA |
| 下载到 ZIP | 解压 Artifacts ZIP，里面的 IPA 才是安装文件，不要再解压 IPA |
| 找不到 AltServer | 检查电脑运行状态、私有网络访问和 Wi-Fi，优先用数据线；见 [排障指南](https://faq.altstore.io/altstore-classic/troubleshooting-guide) |
| 提示不受信任或开发者模式关闭 | 完成系统信任和开发者模式流程，按提示重启 |
| 应用名额已满 | 检查已有个人签名应用，AltStore 也占名额 |
| 分享面板没有本应用 | 个人版不含分享扩展，用聊天相册和文字粘贴 |
| 朋友圈、服务或语音没反应 | 这些功能尚未实现，不是安装问题 |
| 两个应用都叫微信 | 放进不同文件夹，本应用设置页可确认“本地聊天仿真” |

## 其他方案

- 借用 Mac：按 README 的个人版步骤用 Xcode 直接安装，免费签名也需更新。
- 付费开发者账号：标准会员费每年 99 美元或当地币种，可使用开发或 Ad Hoc 分发给已注册设备；仍需 macOS 编译环境，并管理证书和描述文件有效期。见 [会员说明](https://developer.apple.com/programs/enroll/) 和 [分发方式](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)。
- TestFlight：需要会员和 App Store Connect 配置，每个构建最多测试 90 天，外部测试可能需审核。见 [TestFlight 说明](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)。
- App Store：当前直接使用微信名称和图标的仿真定位不适合公开上架。需自有品牌和完整功能，并满足 [审核指南 4.1](https://developer.apple.com/app-store/review/guidelines/#copycats)。

## 真机验收

确认桌面图标名称、首次示例聊天、发文字和图片、编辑身份与时间、模拟回复、修改头像昵称，以及退出重开后的数据保存。个人版不应申请 App Groups 或要求登录微信。

文档整理于 2026-09-22；首次云端编译已通过，真机验收尚待执行。
