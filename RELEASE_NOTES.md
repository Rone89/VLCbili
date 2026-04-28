## 本版本修复

- 修复 DASH→HLS 第一版不能出画/无声：不再把整条 DASH 文件当成单个 HLS 分片。
- 新增 sidx/index_range 解析：下载视频轨和音频轨的索引段，解析每个 subsegment 的 byte range 和 duration。
- HLS media playlist 现在为每个 DASH subsegment 生成 `EXTINF` + `EXT-X-BYTERANGE`，并保留 `EXT-X-MAP` 初始化段。
- 诊断文本标记为 `DASH-to-HLS-sidx`，方便确认运行的是本次分片 HLS 路径。
- HLS 失败仍会兜底旧本地合流，避免高画质完全不可播。

## 说明

这是 DASH→HLS 第二版验证：重点测试 1080P+/4K 是否能出画、有声，以及是否比完整合流更快起播。
