# v0.1.134 - DASH/HLS 首屏加载提速

## 更新内容

- 本地 HLS 代理改为常驻复用，不再每次播放 DASH 分离流时取消并重新启动监听。
- 切换新视频时只清理路由、清单和启动缓存，减少代理冷启动等待。
- 生成 Master Playlist 后立即预取视频和音频的初始化片段以及首个媒体片段，帮助 AVPlayer 更快拿到起播所需数据。
- DASH sidx 索引请求和本地代理 Range 请求统一使用 `Accept-Encoding: identity`，避免 Range 数据被压缩响应干扰。
- AVPlayer 起播缓冲从偏保守模式改成快启模式，降低 `preferredForwardBufferDuration`，并关闭首屏阶段的过度等待。
- 播放项 ready 后使用 `playImmediately(atRate:)`，减少 ready 到真正出画面的延迟。

## 体验变化

- DASH 音视频分离流首屏等待时间更短。
- 切换视频或清晰度时，本地代理启动成本更低。
- 弱网下仍可能短暂停顿，但会更倾向于快速出画，而不是先等较长缓冲。

## 验证建议

- 连续打开多个视频，观察第二个及以后视频是否比之前更快进入播放。
- 播放 4K/HEVC/HDR DASH 分离流，确认能快速出画且有声音。
- 拖动进度条后确认能恢复播放，且音画同步。
- 观察诊断信息，确认本地代理没有 404/502，首个 init/segment 请求正常。

## 打包说明

- GitHub Actions 会构建 Release 配置的未签名 IPA。
- 生成的 `ccbili-unsigned.ipa` 会作为 Release 附件上传。
- 未签名 IPA 需要自行重签名后安装到真机。
