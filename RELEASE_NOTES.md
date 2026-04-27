## 本版本修复

- 恢复 1080P60+ DASH 播放入口：高于 1080P 的清晰度会生成本地 DASH MPD，让 KSPlayer/FFmpegKit 统一读取视频流和音频流。
- 保留 1080P 及以下合流 `durl` 播放兜底，保证普通清晰度继续有声音。
- 播放请求头补充 Cookie/Accept/Connection，提升 B 站 DASH 视频、音频分离流加载成功率。

## 说明

本版本先采用本地 MPD 合流清单方案，避免再次启用双播放器音频旁路。如果少数视频的 1080P60+ 仍黑屏或无声，下一步再改成 FFmpegKit/libav 本地转封装为 MP4 后播放。
