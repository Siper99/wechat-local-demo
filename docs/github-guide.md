# GitHub 操作手册（构建、测试、下载 IPA）

仓库：`Siper99/wechat-local-demo`（私有），默认分支 `main`。
工作流：`.github/workflows/build-ios.yml`，名称“Build iPhone IPA”，**只能手动触发**，推送代码不会自动构建。

命令在 Windows 的 Git Bash 里运行，需要装好 [GitHub CLI](https://cli.github.com/)（`gh`）和 Git。

## 0. 登录（只需一次）

```bash
gh auth status                          # 看是否已登录
gh auth login                           # 未登录时按提示用浏览器登录
gh auth refresh -h github.com -s user   # 需要查账单用量时再加 user 权限
```

## 1. 提交并推送代码

```bash
git status                              # 看改了哪些文件
git add -A
git commit -m "说明这次改了什么"
git push origin main
```

推送只更新代码，不会消耗 Actions 时间。

## 2. 触发构建

命令行：

```bash
gh workflow run build-ios.yml --ref main
```

网页：仓库 → Actions → 左侧 Build iPhone IPA → 右侧 Run workflow → 选 main → Run workflow。

一次构建包含两个任务，都在 macOS 机器上跑：

| 任务 | 内容 | 大约用时 |
|---|---|---|
| build | Xcode 16.4 打包 IPA，并在 iPhone 16（iOS 18.5）模拟器上跑全部界面测试 | 13–16 分钟 |
| ios26 | 用 Xcode 26 在 iOS 26 模拟器上再跑一遍同样的测试，只作参考，不影响 IPA | 12–15 分钟 |

## 3. 查看进度和结果

```bash
gh run list --workflow build-ios.yml --limit 5           # 最近几次，第一列是状态，ID 在后面
gh run watch <运行ID> --exit-status --interval 30        # 盯着直到结束，失败时返回非 0
gh run view <运行ID>                                     # 概要：每个任务成功/失败
gh run view <运行ID> --json jobs --jq '.jobs[]|{name,conclusion}'
```

网页：Actions 页面点进某次运行即可看到每个任务、每一步的日志。

## 4. 下载 IPA 和测试截图

每次运行的产物（Artifacts）保留 7 天：

| 名称 | 内容 |
|---|---|
| `WeChat-Simulator-unsigned` | 未签名的 IPA，用 SideStore 安装 |
| `iPhone-UI-verification` | iOS 18.5 测试截图、界面结构、录屏 |
| `iPhone-UI-verification-iOS26` | iOS 26 测试截图等 |

```bash
gh run download <运行ID> -n WeChat-Simulator-unsigned -D ipa
gh run download <运行ID> -n iPhone-UI-verification -D shots
```

网页：运行详情页最下方 Artifacts，点名字下载 zip。IPA 的 zip 解压后是 `WeChat-Simulator-unsigned.ipa`。

安装：用同一个 SideStore 账号覆盖安装，聊天记录保留；在“我 → 设置 → 关于”确认版本号。

## 5. 测试失败时怎么查

```bash
gh run view <运行ID> --log-failed | grep -E "error:|failed"     # 看哪一行断言失败
gh run view <运行ID> --log | grep -E "Test Case .*(passed|failed)"
```

更细的信息在测试截图产物里：

- `manifest.json`：把随机文件名对应到截图名称（如 `17-contact-profile`）和所属测试。
- `App UI hierarchy ... .txt`：失败时刻的界面元素树，可以看停在哪个页面、有没有某个按钮。
- `.mp4`：整个测试的屏幕录像。

## 6. 查看 Actions 剩余时间

网页：<https://github.com/settings/billing/usage>，筛选 Actions。

命令行（先做第 0 步的 `gh auth refresh ... -s user`）：

```bash
gh api users/Siper99/settings/billing/usage
```

计费规则：私有仓库 macOS 机器按 10 倍计分钟。免费版每月 2,000 分钟，约等于 200 分钟 macOS；一次完整构建约 30 分钟 macOS，折合约 300 分钟。公开仓库用标准机器不计费。

## 7. 其他常用

```bash
gh repo view Siper99/wechat-local-demo --json visibility   # 仓库是公开还是私有
gh api repos/Siper99/wechat-local-demo/actions/runs/<运行ID>/artifacts --jq '.artifacts[]|{name,size_in_bytes,expires_at}'
gh run cancel <运行ID>                                      # 发现提交有误时取消，省时间
gh run rerun <运行ID> --failed                              # 只重跑失败的任务
```

注意：在 Git Bash 里用 `gh api` 时路径**不要以 `/` 开头**，否则会被改写成 `C:/Program Files/Git/...` 导致 404。
