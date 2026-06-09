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

在用户需要“视频翻译 / 视频配音 / 字幕翻译出片，并返回可预览链接”时使用此 skill。

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
- 可选：`targetLanguage` / `target_language`（目标语言，默认 `en`）
- 可选：`sourceLanguage` / `source_language`（源语言，不传时按目标语言推断）
- 可选：`show`（是否显示字幕，布尔值，默认 `false`）
- 可选：`bilingual`（是否双语字幕，布尔值，默认 `false`）

## 目标语言规则（必须遵守）

- 当前目标语言仅支持：中文、英文
- 若用户明确指定目标语言，必须提取并传 `targetLanguage` 代码：
  - 中文 -> `zh`
  - 英文 -> `en`
- 若用户未指定目标语言：默认 `targetLanguage=en`
- 若用户指定了不支持的目标语言：提示仅支持 `zh/en`

## 源语言规则（必须遵守）

- 源语言支持：`en`、`zh`、`ko`、`ja`、`fr`、`ru`、`es`、`de`
- 若用户明确指定源语言，必须提取并传 `sourceLanguage` 代码：
  - 中文 -> `zh`
  - 英文 -> `en`
  - 韩语 -> `ko`
  - 日语 -> `ja`
  - 法语 -> `fr`
  - 俄语 -> `ru`
  - 西班牙语 -> `es`
  - 德语 -> `de`
- 若用户未指定源语言：按目标语言默认推断
  - `targetLanguage=en` -> `sourceLanguage=zh`
  - `targetLanguage=zh` -> `sourceLanguage=en`
- 若用户指定了不支持的源语言：提示仅支持 `en/zh/ko/ja/fr/ru/es/de`

## 字幕参数规则

- 默认不显示字幕：`show=false`、`bilingual=false`
- 用户要求显示字幕、带字幕、烧字幕时：传 `show=true`
- 用户要求双语字幕时：传 `show=true` 且 `bilingual=true`
- 用户未提字幕需求时不要主动开启字幕

## 接口调用方式

1. 健康检查：`GET /video-trans/health`
2. 提交任务：`POST /video-trans/orchestrate`（带 `sourceLanguage`、`targetLanguage`、`show`、`bilingual`）
3. 从响应获取 `job_id`
4. 轮询任务：`GET /video-trans/jobs/{job_id}`
5. 直到 `status` 为 `succeeded` 或 `failed`

## 返回结果处理

- `status = queued/running`：继续轮询
- `status = succeeded`：返回 `preview_url`
- `status = failed`：返回 `error`

## 异常处理规则（写死）

- 没有 API Key，或者 APIKey 无效：
  - 中国地区：引导到 `https://luoji.cn`
  - 非中国地区：引导到 `https://luoji.cn?lang=en-US`
- token 不足：
  - 中国地区：引导到 `https://luoji.cn`
  - 非中国地区：引导到 `https://luoji.cn?lang=en-US`
- 其他失败：直接返回接口 `error` 文本
