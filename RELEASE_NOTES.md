## 本版本修复

- 继续使用 AVPlayer + DASH→HLS 方案，不回退 mpv 或完整下载合流作为主路径。
- 新增 HLS 子资源代理：HLS 清单内的 DASH 分片 URL 改为 `ccbili-dash://` 自定义 scheme，由 `AVAssetResourceLoaderDelegate` 统一转回 HTTPS 请求。
- 代理请求会补齐 Cookie/Referer/User-Agent/Range，解决 AVPlayer 直接读取远程 byte-range 子资源时可能丢请求头导致黑屏无声的问题。
- 保留 sidx 分片 HLS 清单生成，诊断文本标记为 `DASH-to-HLS-proxy`。
- 代理路径失败时仍保留旧本地合流兜底。

## 说明

这是 AVPlayer + DASH→HLS 第三版验证：重点测试 1080P+/4K 是否能出画、有声，以及是否比完整合流更快。
