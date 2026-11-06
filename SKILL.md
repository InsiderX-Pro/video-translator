---
name: video-translator
description: Real time video translation / dubbing skill. Translate user-provided video (file or URL) and return preview_url. 适用于视频直译、视频翻译、视频配音、字幕翻译出片。
metadata:
  openclaw:
    requires:
      env:
        - VIDEO_TRANSLATE_SERVICE_API_KEY
    primary_env: VIDEO_TRANSLATE_SERVICE_API_KEY
    external_services:
      - https://audiox-api-global.luoji.cn
    support_url: https://luoji.cn
    privacy_url: https://luoji.cn
    runtime_requirements:
      - curl
      - python3
---

# Video Translator

在用户需要"视频翻译 / 视频配音 / 字幕翻译出片，并返回可预览链接"时使用此 skill。

## 检索关键词

- 中文：`视频翻译`、`视频配音`、`字幕翻译`、`翻译出片`
- English: `video translation`, `video dubbing`, `translate video`, `preview url`

## 固定服务地址

- Base URL 固定为：`https://audiox-api-global.luoji.cn`
- 不使用本地服务地址。

## 何时调用

- 用户给了视频文件，或给了可访问的视频 URL。
- 用户目标是拿到翻译后视频的 `preview_url`。

## 输入要求

- 必须二选一：
- `video`：二进制视频文件（multipart 字段名固定 `video`）
- `video_url`：可访问的 `http(s)` 视频链接
- `api_key`：请求头 `Authorization: Bearer <api_key>`
- 如果使用脚本，必须设置环境变量 `VIDEO_TRANSLATE_SERVICE_API_KEY`
- 可选：`model`（译制模型，`podcast` / `pro` / `normal`，不传等于 `podcast`）
- 可选：`targetLanguage` / `target_language`（目标语言，默认 `en`）
- 可选：`sourceLanguage` / `source_language`（源语言，不传时按模型和目标语言推断）
- 可选：`show`（是否显示字幕，布尔值，默认 `false`）
- 可选：`bilingual`（是否双语字幕，布尔值，默认 `false`）

## 模型规则（必须遵守）

| `model` | 产品 | 源语言 | 目标语言 | 说明 |
| --- | --- | --- | --- | --- |
| `podcast`（默认） | 播客直译 | 见下方方向规则 | `zh` / `en` | 原有行为，出片前做深度优化 |
| `pro` | AI 视频直译 Pro | `zh` / `ko` / `ja` / `en` | `zh` / `ko` / `en` / `fr` / `es` / `th` / `vi` / `lo` | 保留原声音色与情绪 |
| `normal` | AI 视频直译 | 同 `pro` | 同 `pro` | 相似音色，保留情绪 |

- 用户没有提到模型时不传 `model`，保持默认。
- 用户提到 "Pro / 保留原声音色" 时传 `model=pro`；提到 "AI 视频直译 / 普通版" 时传 `model=normal`。
- 用户要的目标语言只有 `podcast` 支持不了（例如法语、泰语、越南语、老挝语）时，用 `model=normal` 并说明。
- `pro` / `normal` 允许源语言和目标语言相同，此时只重新配音。
- `pro` / `normal` 只接受 `mp4` / `mov` / `webm` / `mkv` 视频。

## 语言规则（必须遵守）

语言一律转成 ISO 639-1 代码再传：中文 `zh`、英文 `en`、韩语 `ko`、日语 `ja`、法语 `fr`、俄语 `ru`、西班牙语 `es`、德语 `de`、泰语 `th`、越南语 `vi`、老挝语 `lo`。

`model=podcast`（默认）的方向是固定的：

- `targetLanguage=en`：只能 `sourceLanguage=zh`（中文视频译成英文）
- `targetLanguage=zh`：`sourceLanguage` 只能是 `en` / `ko` / `ja` / `fr` / `ru` / `es` / `de`
- 未指定目标语言：`targetLanguage=en`
- 未指定源语言：目标 `en` 时用 `zh`，目标 `zh` 时用 `en`
- 用户指定了别的组合（例如韩语译成英文）：不要硬传，提示 `podcast` 只支持这两个方向，可改用 `model=normal`

`model=pro` / `normal`：

- `sourceLanguage` 只能是 `zh` / `ko` / `ja` / `en`，未指定时用 `zh`
- `targetLanguage` 只能是 `zh` / `ko` / `en` / `fr` / `es` / `th` / `vi` / `lo`，未指定时用 `en`

接口会按同样规则校验，不符合时 `POST /video-trans/orchestrate` 直接返回 `400` 并说明允许的取值。

## 字幕参数规则

- 默认不显示字幕：`show=false`、`bilingual=false`
- 用户要求显示字幕、带字幕、烧字幕时：传 `show=true`
- 用户要求双语字幕时：传 `show=true` 且 `bilingual=true`
- 用户未提字幕需求时不要主动开启字幕

## 接口调用方式

1. 健康检查：`GET /video-trans/health`
2. 提交任务：`POST /video-trans/orchestrate`（带 `model`、`sourceLanguage`、`targetLanguage`、`show`、`bilingual`）
3. 从响应获取 `job_id`
4. 轮询任务：`GET /video-trans/jobs/{job_id}`
5. 直到 `status` 为 `succeeded` 或 `failed`

## 返回结果处理

- `status = queued/running`：继续轮询
- `status = succeeded`：返回 `preview_url`（成片链接有时效，提醒用户及时下载）
- `status = failed`：返回 `error`

## 计费说明

- 任务按积分计费，从 API Key 所属账号的积分余额扣除；`podcast` 按「播客直译」费率，`pro` / `normal` 按对应模型费率。
- 余额不足时 `error` 为 `INSUFFICIENT_BALANCE`。

## 异常处理规则

- 没有 API Key，或者 API Key 无效：
  - 中国地区：引导到 `https://luoji.cn/studio/api-keys`
  - 非中国地区：引导到 `https://luoji.cn/studio/api-keys?lang=en-US`
- 积分不足（`INSUFFICIENT_BALANCE`）：
  - 中国地区：引导到 `https://luoji.cn/studio/wallet`
  - 非中国地区：引导到 `https://luoji.cn/studio/wallet?lang=en-US`
- 其他失败：直接返回接口 `error` 文本
