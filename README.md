<h1 align="center">
  <br>
  <img src="assets/icons/icon.png" width="150"/>
  <br>
  纯粹直播（Pure Live）
  <br>
</h1>

<h4 align="center">一款开源的第三方多平台直播聚合播放器</h4>
<h4 align="center">A Third-party Live Stream Aggregator Built with Flutter</h4>

<p align="center">
  <img alt="License" src="https://img.shields.io/github/license/DaiYuannn/PureLive_Multi-screen?color=blue">
  <img alt="Latest Release" src="https://img.shields.io/github/v/release/DaiYuannn/PureLive_Multi-screen">
  <img alt="Stars" src="https://img.shields.io/github/stars/DaiYuannn/PureLive_Multi-screen?color=yellow">
</p>

> ⚠️ **本项目仅用于学习与技术交流，请遵守当地法律法规与目标平台服务条款。**

---

## 🪟 Windows 主线快速开始（推荐）

当前仓库维护策略为：**Windows 主线优先，Android / Android TV 为辅**。

最新版下载（Releases）：

- https://github.com/DaiYuannn/PureLive_Multi-screen/releases/tag/v2.0.14%2B25-multilive-20260325

### 1. 环境建议

- 使用 `.fvmrc` 指定的 Flutter `stable`
- 在本仓库中优先使用 `fvm flutter ...` 与 `fvm dart ...`
- 国内网络建议启用镜像：

```powershell
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
```

### 2. 常用命令（Windows）

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm dart format .
fvm flutter run -d windows
```

Windows 安装包制作与快速卸载说明：

- [docs/windows_packaging_and_uninstall.md](docs/windows_packaging_and_uninstall.md)

### 3. 多直播改造路线（当前版本建议）

- **Phase 1（优先）**：单窗口多分屏同屏播放（1/2/4/6/9）
  - 每个分屏独立播放器实例
  - 默认只有焦点分屏有声音
  - 退出页面统一释放播放器与弹幕资源
- **Phase 2（增强）**：系统级多窗口（Windows）
  - 主窗口管理房间，子窗口各自播放
  - 处理窗口焦点、关闭同步、托盘行为

### 4. 实施前提示

- 多分屏模式不要复用全局单例播放器状态
- 低配机器避免所有分屏同时开启弹幕与高码率
- 做系统多窗口前需先处理单实例锁逻辑

---

## 📌 项目来源与当前定位

本仓库基于开源项目 pure_live 的公开代码继续维护与改造：

- 上游来源：liuchuancong/pure_live（参考版本：v2.0.14）
- 早期来源：Jackiu1997/pure_live
- 当前定位：Windows 主线优先（个人自用），Android / Android TV 为辅

为了便于后续同步与合规发布，本仓库遵循以下原则：

- 保留并标注上游项目来源与作者信息
- 对新增/修改内容进行可追踪说明
- 优先复用现有 Flutter 业务逻辑，平台差异层尽量收敛

详细说明见：

- [NOTICE.md](NOTICE.md)

---

## 🚧 当前任务进度（2026-03-25）

- ✅ Windows 安装包流程打通（Inno EXE）
- ✅ 安装向导支持创建桌面快捷方式（默认勾选）
- ✅ 同屏播放主链路完成第一轮迭代（单窗口多分屏）
- ✅ 同屏新增“2主多副（左侧双主纵向）”与“自由布局（拖拽+缩放+吸附）”
- ✅ Android / Android TV 辅助链路恢复并进入持续适配
- 🔄 Android / TV 同屏体验正在规划专项适配（性能档位 + 遥控器焦点）
- ⏳ 真机专项验证与回归（Android 手机、Android TV）

---

## 🗺️ 后续计划（Roadmap）

短期（P0）：

- Android 同屏 2/4 屏稳定性优化
- 同屏音频策略与资源占用优化（默认焦点出声）
- TV 遥控器焦点导航与确认键行为完善

中期（P1）：

- Android 高性能机型开放 6/9 屏实验配置
- 同屏布局与交互统一（Windows / Android / TV）
- 同屏异常恢复与失败重试体验优化

长期（P2）：

- Windows 真多窗口模式（主窗管理 + 子窗独立播放）
- Windows / Android / TV 一致的可观测日志与问题定位能力

---

## 🧭 平台支持状态

| 平台 | 当前状态 | 说明 |
|------|---------|------|
| Windows | ✅ 主线稳定 | 当前优先维护与验证平台 |
| Android | ✅ 可用 | 持续优化同屏性能与稳定性 |
| Android TV | 🔄 适配中 | 重点完善遥控器焦点与交互体验 |

---

## 📺 支持平台

- 哔哩哔哩（Bilibili）  
- 虎牙直播（Huya）  
- 斗鱼直播（Douyu）  
- 快手（Kuaishou）  
- 抖音（Douyin）  
- 网易 CC 直播  
- 自定义 M3U8 源（支持本地/网络导入）

支持按分区筛选、隐藏不关注平台，节省流量与内存。

---

## ✨ 核心功能

- ✅ **多端支持**：Windows（主线）/ Android / Android TV（辅助）  
- ✅ **多播放器切换**：内置 IJKPlayer 与 MPV Player（Android/TV）  
- ✅ **自定义直播源**：通过 M3U/M3U8 导入网络或本地直播流  
- ✅ **数据同步与备份**：支持 WebDAV 同步、本地导出/导入配置  
- ✅ **弹幕增强**：支持弹幕过滤、合并与显示优化  
- ✅ **定时关闭**：可设置倒计时自动退出应用  
- ✅ **用户系统（可选）**：基于 [Supabase](https://supabase.com/) 实现注册/登录（需邮箱白名单认证）

> 💡 提示：如需使用 Supabase 功能，可自行 Fork 项目并在 Supabase 控制台部署服务。

---

## 🧩 同屏播放新增功能（当前版本）

以下为当前仓库已落地的同屏增强能力（单窗口多分屏）：

- ✅ **同屏入口优化**：房间卡片支持「加入同屏队列」与「立即同屏」两种快捷操作。
- ✅ **三来源添加房间**：同屏页支持从「收藏 / 历史 / 队列」三标签快速添加。
- ✅ **布局增强**：支持等分、1主多副、2主多副；支持主副比例滑杆 + 拖动分割条实时调整。
- ✅ **主窗高亮**：主窗格边框强化显示，便于快速识别主屏。
- ✅ **直接拖拽重排**：无需编辑模式，窗格可直接拖拽调整顺序。
- ✅ **全屏增强**：支持真实全屏沉浸（覆盖任务栏）；顶部悬停唤起控制栏，右侧悬浮按钮退出全屏。
- ✅ **容量自适应**：同屏数量上限按当前窗口尺寸自动识别，采用性能优先策略。
- ✅ **快捷键增强**：
  - `1-9` 切换焦点窗格（全屏时可直接切换全屏目标）
  - `F` 单窗全屏切换
  - `Delete` 删除焦点窗格（支持撤销）
  - `M / 0 / R / +/- / Shift +/-` 静音、刷新与音量调整
- ✅ **音频策略**：支持单焦点 / 混音 / 主窗优先三种模式，支持总音量与单窗音量独立调节。
- ✅ **删除可撤销**：移除窗格后可在提示条中快速撤销。

详细操作说明请查看：[docs/multi_live_shortcuts_operations.md](docs/multi_live_shortcuts_operations.md)

---

## 🤝 贡献方式

- 欢迎通过 Issue 提交问题反馈或功能建议。
- 欢迎通过 Pull Request 提交修复与改进。
- 提交前建议先运行：`fvm flutter analyze`、`fvm flutter test`、`fvm dart format .`

---

## 🔒 声明与合规

- 本项目为 **非盈利性开源软件**，遵循 **[GNU AGPL-3.0 协议](LICENSE)**。  
- **不提供任何 VIP 解锁、视频破解或盗链服务**。高清直播需您在对应平台拥有合法账号权限。  
- 所有直播内容（视频、音频、图像等）**版权归属原平台所有**，本软件仅作技术聚合与转码展示。  
- 若您认为本项目侵犯您的合法权益，请通过 [GitHub Issue](https://github.com/DaiYuannn/PureLive_Multi-screen/issues) 联系我们，我们将及时处理。
- 上游继承、改动范围与归属声明见 [NOTICE.md](NOTICE.md)。

---

## 🛡️ 隐私策略

- 本应用 **不开源收集任何用户隐私数据**。  
- 所有请求均直接发往官方接口（如 Bilibili、Douyu 等），**无中间代理或数据中转**。  
- 用户 Cookie 仅用于本地身份认证（如 B站高清直播），**不会上传或存储到任何服务器**。  
- 应用无广告、无追踪、无后台服务。若杀毒软件误报，请自行判断或拒绝使用。

---

## 🛠 使用说明

### ▶️ 播放器选择
- **Android/TV**：可在设置中切换 IJKPlayer 或 MPV Player。
- **字幕支持**：
  - Android：使用系统自带实时字幕功能
  - Windows：启用 Windows 11 的 *Live Captions*（任务栏搜索即可）

### 🔑 Bilibili 高清直播
因平台限制，观看高清直播需登录。  
您可通过应用内“三方认证”获取 Cookie，**仅用于本地请求，不上传任何信息**。

### 📥 导入 M3U 源
1. 打开 App → 设置 → 备份与还原 → 导入 M3U 源  
2. 支持从 [123云盘](https://www.123pan.com/s/Jucxjv-NwYYd.html) 下载示例源  
3. 源转换工具推荐：[直播源转换器](https://guihet.com/tvlistconvert.html)

> 📂 存储位置：
> - **Android**：清除缓存即可移除导入内容  
> - **Windows**：配置文件位于  
>   `C:\Users\<用户名>\AppData\Local\com.mystyle\pure_live\categories.json`

---

## ❓ 常见问题

| 问题 | 解决方案 |
|------|--------|
| 关闭软件时弹出“快速异常检测失败” | Windows 特定提示，**不影响使用**，可忽略 |
| Windows 恢复手机备份后无画面、仅有弹幕 | 进入 **设置 → 播放器**，重新选择或重置播放器 |
| 部分设备无法播放（黑屏/卡顿） | 尝试切换播放器（IJK ↔ MPV），或检查硬件解码支持 |

> ⚠️ **华为设备兼容性**：因系统框架限制，部分华为机型可能存在卡顿，暂无优化方案，敬请谅解。