## 本版本说明

### 新增功能

- 视频详情页实现“播放状态联动滚动”：播放中下滑页面时视频窗口会悬浮固定在顶部，文字、按钮和评论继续滚动。
- 暂停播放后，视频窗口恢复为普通内容，跟随页面一起向上滚动并消失。

### 技术说明

- 通过 `GeometryReader` + `PreferenceKey` 监听视频窗口在滚动坐标系中的 `minY`。
- 播放中根据 `pinnedTopOffset - minY` 动态设置视频视图 `offset(y:)`，等价于 UIKit 中修改 `CGRect.origin.y` 产生固定视觉效果。
- 播放状态继续由播放器回调同步到 `isVideoPlaying`，暂停时 `offset` 立即归零。

## 说明

未签名 IPA 会作为 Release 附件上传，适合后续自行签名或侧载测试。