## 本版本修复

- 按你的建议新增 DASH → HLS 流式播放路径：1080P+/1080P60/4K 优先生成本地 HLS master/video/audio 清单交给 AVPlayer 播放。
- HLS 清单使用 B 站 DASH 的 `segment_base.initialization` 作为 `EXT-X-MAP`，视频轨和音频轨分别生成 media playlist，再由 master playlist 关联。
- 该方案不再等待整段下载合流，目标是保留系统播放器稳定性的同时实现接近 PiliPlus 的流式起播。
- 如果 DASH→HLS 清单播放失败，仍保留旧的本地合流兜底，避免高画质完全不可播。

## 说明

这是 DASH→HLS 第一版验证：请重点测试 1080P+/4K 是否能出画、有声、加载是否明显快于完整合流。
