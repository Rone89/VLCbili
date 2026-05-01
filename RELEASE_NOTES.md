## v0.1.156-202605011450

### 修复

- 将 1080P+ 等 DASH 分离音视频播放从本地 HLS master playlist 改为本地 DASH MPD manifest，交给 VLCKit/libVLC 原生 DASH 解析。
- 本地 MPD 中的视频、音频 `BaseURL` 都走代理，继续补齐 B 站 CDN 需要的 Referer、Cookie、User-Agent、Range 等请求头。
- 代理支持 `application/dash+xml` 清单响应，播放诊断会显示 MPD 的 range、时长和 codec 信息。

### 说明

VLCKit 不需要 dash-to-hls；但 B 站接口返回的是独立 video/audio m4s 地址，而不是一个可直接播放的 MPD 文件。本版本改为在本地生成 MPD，避免 VLC 一直反复读取 HLS master 却不进入分片请求。

### 附件

Release 会附带未签名 IPA，适合后续自行签名或侧载测试。
