# 本版本说明

## 修复问题

- 重构播放器横竖屏切换，不再用 SwiftUI `rotationEffect` 手动旋转视频和控制层。
- 全屏播放改为系统方向转场，由 `UIWindowScene.requestGeometryUpdate` 和 `viewWillTransition(to:with:)` 驱动。
- AVPlayerLayer 的 frame 更新通过 `CATransaction` 控制隐式动画，避免和 UIView/系统旋转动画打架。
- 横竖屏切换时显式调用 `layoutIfNeeded()`，减少约束和 SwiftUI 布局不同步导致的跳变。
- 固定 `videoGravity = .resizeAspect`，避免容器尺寸变化瞬间画面拉伸抖动。

## 打包说明

- GitHub Actions 会构建 Release 配置的未签名 IPA。
- 生成的 `ccbili-unsigned.ipa` 会作为 Release 附件上传。