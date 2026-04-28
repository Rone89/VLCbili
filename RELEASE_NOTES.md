## 本版本修复

- 参考 PiliPlus/公开 Bilibili API 的 DASH 播放方式：1080P+/1080P60/4K 不再整段下载合流后播放，改为 `libmpv` 直接流式加载视频轨 + 音频轨。
- DASH 音频改为随 `loadfile` 一起传入 `audio-file`，减少先出画后补音轨的问题。
- 修正 mpv HTTP Header 为逐行格式，并补充 Referer/User-Agent/Cookie，提升 B 站 CDN 分离流直连成功率。
- mpv 打开硬解 `videotoolbox`，降低高分辨率播放压力。
- mpv 播放路径接入进度、暂停、拖动和横屏状态，保持与原控制层一致。

## 说明

这个版本的目标是解决 1080P+ 和 4K 首次加载很久的问题：不再等待完整下载与本地合流，而是像 PiliPlus 一样让播放器流式读取 DASH 双轨。
