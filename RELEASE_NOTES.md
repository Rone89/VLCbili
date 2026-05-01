## v0.1.158-202605012238

### 修复

- 普通 DURL 和 1080P+ DASH 分离流改为由 VLCKit 直接访问 B 站 CDN，不再经由本地代理二次转发，避免画面和声音播放速度异常。
- VLC 媒体请求直接注入 `User-Agent`、`Referer` 和登录 Cookie，高画质音频继续通过 `input-slave` 交给 VLC 同步。
- 播放开始时显式重置 VLC 播放速率为 1x，并更新诊断为 `direct-durl` / `direct-vlc-slave`。

### 附件

Release 会附带未签名 IPA，适合后续自行签名或侧载测试。
