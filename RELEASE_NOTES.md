## 本版本修复

- 为本地 HLS 代理补充 `NSAllowsLocalNetworking`，避免 AVPlayer 访问 `127.0.0.1` HLS 分片被 ATS/本地网络策略拦截。
- 播放诊断从 3 行扩展到 8 行，并把 HLS 诊断换行显示，避免 `manifest/proxy` 信息被截断。
- 增加 AVPlayerItem 状态诊断：显示 `player=ready/failed/unknown` 以及失败原因。
- 保留 HLS manifest 与 proxy 请求诊断：`manifest=v.../a...`、`proxy#... status req/res bytes`。

## 说明

请安装后重新测试 1080P+/4K，并把完整黄色诊断发我。重点看是否有 `proxy#`，以及 `player=` 是 ready、failed 还是 unknown。
