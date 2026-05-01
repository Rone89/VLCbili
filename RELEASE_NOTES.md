## v0.1.154-202605011404

### 修复

- 修复安装后视频一直加载的问题：本地媒体代理现在会边下载边转发给 VLC，不再等待整段视频完整下载后才响应。
- 媒体分片请求固定使用 `Accept-Encoding: identity`，避免 CDN 压缩破坏字节范围数据。

### 继续包含

- 播放内核使用 MobileVLCKit / VLCMediaPlayer。
- 保留播放控制、进度拖动、清晰度切换、播放历史恢复和横屏全屏体验。
- DASH 分离音视频继续通过本地 HLS manifest/proxy 合成为 VLC 可播放入口。

### 附件

Release 会附带未签名 IPA，适合后续自行签名或侧载测试。
