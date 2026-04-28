## 本版本修复

- 确认 KSPlayer `set(urls:)` 是播放列表语义，不是 DASH 音视频合流，因此恢复 DASH 使用 libmpv。
- 修复 libmpv 嵌入方式：`wid` 改为绑定 `UIView` 本身，而不是 `CALayer`，用于解决有声黑屏/无画面问题。
- 播放诊断文本增加缩放和多行限制，减少超出视频框的问题。

## 说明

请测试 1080P+/1080P60。如果仍黑屏，继续反馈诊断文本和是否有声音；下一步将改用 mpv render API 或 AVFoundation 本地合流兜底。
