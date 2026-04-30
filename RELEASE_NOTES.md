# v0.1.130 - DASH 秒开 HLS Manifest 核心

## 更新内容

- 新增轻量 `generateHLSManifest(...) -> String` 核心函数，把 DASH fMP4 元数据动态映射为 HLS m3u8 字符串。
- 使用 `#EXT-X-MAP` 映射 DASH 初始化片段，解决 AVPlayer 无法加载 fMP4 头文件的问题。
- 强制输出 `#EXT-X-VERSION:7`，满足 CMAF/fMP4 播放要求。
- Master Playlist 根据 HDR/杜比/HDR 中文清晰度标记自动追加 `VIDEO-RANGE=PQ`。
- 所有 playlist URL 和 segment URL 均校验为绝对 URL，避免 AVPlayer 解析相对路径失败。
- 现有 DASH-to-HLS 本地代理已改为调用新生成器，继续用本地 HTTP 服务动态托管 m3u8。

## 性能说明

- 字符串拼接只在 async DASH 取流路径里执行，不放到 SwiftUI 主线程。
- 预分配 playlist 行数组容量，避免频繁扩容。
- 视频和音频 SIDX 分片仍并发解析，减少首帧前等待。

## 同步说明

- 视频和音频分别生成独立 media playlist，由 master playlist 通过 `EXT-X-MEDIA` 绑定。
- 分片时长直接来自 SIDX timescale，避免手写时长导致音画漂移。
- fMP4 头通过 `EXT-X-MAP` + byte range 指向原始初始化区间，避免 AVPlayer 找不到 moov/moof 头。

## 打包说明

- GitHub Actions 会构建 Release 配置的未签名 IPA。
- 生成的 `ccbili-unsigned.ipa` 会作为 Release 附件上传。
- 未签名 IPA 需要自行重签名后安装到真机。
