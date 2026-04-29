## 本版本修复

- 视频详情页播放器在 `AVPlayerItem.status == .readyToPlay` 后读取视频轨道原始尺寸，并按真实宽高比自动调整窗口高度。
- 播放器高度限制为屏幕高度的 70%，避免竖屏视频撑满页面。
- GitHub Actions 支持手动填写 `release_tag` 生成未签名 IPA 并创建 GitHub Release。

## 说明

未签名 IPA 会作为 Release 附件上传，适合后续自行签名或侧载测试。
