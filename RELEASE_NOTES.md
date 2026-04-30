# 本版本说明

## 封面展示优化

- 搜索页视频结果卡片参考首页 `HomeRecommendationCardView` 的封面规则。
- 个人主页投稿视频卡片参考首页 `HomeRecommendationCardView` 的封面规则。
- 新增通用视频卡片的首页布局模式：固定卡片高度、固定封面高度、统一裁剪、统一圆角和描边阴影。
- 保留历史页等列表场景原有普通样式，不影响继续观看进度展示。

## 打包说明

- GitHub Actions 会构建 Release 配置的未签名 IPA。
- 生成的 `ccbili-unsigned.ipa` 会作为 Release 附件上传。