## v0.1.153-202605011349

### 主要变更

- 将视频播放内核从系统 AVPlayer 切换为 MobileVLCKit / VLCMediaPlayer。
- 保留现有播放控制、进度拖动、清晰度切换、播放历史恢复和横屏全屏体验。
- DASH 分离音视频继续通过本地 HLS manifest/proxy 合成为 VLC 可播放入口，普通 DURL 也通过本地代理附带 B 站所需请求头。
- 移除旧 AVPlayer 播放视图和未使用的 AVFoundation DASH 合成代码。

### 构建说明

- 新增 CocoaPods 依赖：`MobileVLCKit 4.0.0a2`。
- 本地首次构建需执行 `pod install`，之后使用 `ccbili.xcworkspace` 打开项目。
- GitHub Actions 已切换为先安装 Pods，再使用 workspace 构建未签名 IPA。

### 附件

Release 会附带未签名 IPA，适合后续自行签名或侧载测试。
