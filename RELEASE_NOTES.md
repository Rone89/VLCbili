## 本版本修复

- 参考 PiliPlus 的 UGC 取流实现，主接口改回 `/x/player/wbi/playurl`。
- WBI 参数同步 PiliPlus：`fnval=4048`、`fourk=1`、`voice_balance=1`、`gaia_source=pre-load`、`isGaiaAvoided=true`、`web_location=1315873`、`try_look=1`。
- 移除 WBI 请求中的 `platform=pc` / `high_quality`，避免影响高画质 DASH 返回。
- 旧版 `/x/player/playurl` 仅作为接口失败时的 fallback。
- 黄色诊断文本增加接口来源：`DASH/wbi` 或 `DASH/legacy`。

## 说明

请测试后反馈黄色诊断。如果 PiliPlus 参数生效，应看到 `DASH/wbi selected=112` 或 `dash=[112,...]`。
