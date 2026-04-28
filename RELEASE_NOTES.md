## 本版本修复

- DASH→HLS 改为本地 HTTP 代理方案：AVPlayer 播放 `127.0.0.1` 的 HLS 分片地址。
- 新增 `LocalHLSProxyServer`，使用 `Network.framework` 在 App 内启动极简本地服务，按分片请求转发到 B 站 DASH URL。
- 本地代理会补齐 Cookie/Referer/User-Agent/Range，避免 AVPlayer 直接请求远程 DASH 分片时丢请求头。
- HLS 清单继续使用 sidx 解析后的 `EXT-X-BYTERANGE` 分片，但媒体 URL 改成本地代理路由。
- 诊断文本标记为 `DASH-to-HLS-local`。

## 说明

这是 AVPlayer + DASH→HLS 第四版验证：重点测试 1080P+/4K 是否能出画、有声，以及加载速度是否改善。
