## 本版本修复

- 明确切回 DASH→HLS 路径：1080P+/1080P60/4K 不再走 `DASH-AVComposition`，改回 `DashHLSManifestService` 生成本地 HLS 清单。
- 恢复本地 HLS 代理 `LocalHLSProxyServer`，HLS 分片 URL 指向 `127.0.0.1:28757`，由 App 转发到 B 站 DASH URL 并补齐 Cookie/Referer/User-Agent/Range。
- 诊断文本标记改为 `DASH-to-HLS-local`，用于确认本次确实采用 DASH→HLS 方案。
- 保留纯原生 AVPlayer 播放层，AVPlayer 直接播放本地 master.m3u8。

## 说明

上一版截图显示 `DASH-AVComposition`，说明确实没有走 DASH→HLS。本版本已把高画质分支切回 DASH→HLS-local。
