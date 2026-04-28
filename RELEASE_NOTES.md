## 本版本修复

- 新增 `DASHAssetLoader`：基于 `AVMutableComposition` 将远程 Video Track 与 Audio Track 合成为一个 `AVPlayerItem`。
- 1080P+/1080P60/4K 优先走 `DASH-AVComposition` 路径，符合 JKVideo 的核心思路：先识别 DASH 音画分离，再交给播放器统一播放。
- `DASHAssetLoader.createPlayerItem(videoURL:audioURL:headers:)` 会异步加载 video/audio tracks，确保 tracks 就绪后再插入 composition。
- 注入 Referer/User-Agent/Cookie/Accept 等请求头到两个 `AVURLAsset`，降低 B 站 CDN 403 风险。
- 合成时保留原视频 `preferredTransform` 和 `naturalSize`，避免方向错误。
- 如果 AVComposition 合成失败，仍保留本地合流兜底，避免高画质完全不可播。

## 原理说明

Bilibili 1080P+ 通常是 DASH 音画分离：视频 URL 只有画面，音频 URL 只有声音。单 URL AVPlayer 无法自动合并两条远程流，所以会出现有画无声或解析失败。本版本通过 `AVMutableComposition` 把远程视频轨和音频轨合成一个逻辑媒体项，再交给 AVPlayer 播放。
