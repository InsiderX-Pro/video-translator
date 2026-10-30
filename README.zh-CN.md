![video-translator 头图](assets/readme/header-simple.svg)

# video-translator 中文说明

`video-translator` 是一个用于调用在线视频翻译 / 配音服务的 Codex skill。它接收本地视频文件或可访问的视频 URL，提交异步翻译任务，轮询任务状态，并在成功后返回最终的 `preview_url`。

## 演示视频

<video src="assets/readme/demo-zh-CN.mp4" controls preload="metadata" width="720"></video>

[观看中文版演示视频](assets/readme/demo-zh-CN.mp4)

## 适合什么场景

- 视频直译：把用户提供的视频翻译成目标语言。
- 视频配音：通过线上服务生成翻译后视频。
- 字幕翻译出片：按需开启单语或双语字幕。
- 自动返回预览：任务完成后把 `preview_url` 交给用户。

## 工作流程

![视频翻译工作流](assets/readme/pipeline.svg)

1. 接收本地视频文件或 `video_url`。
2. 进行预处理、背景音分离、说话人分离、ASR、翻译、声音克隆、配音生成、字幕渲染和最终混音。
3. 调用 `POST /video-trans/orchestrate` 提交异步任务，并使用 `job_id` 轮询状态。
4. 成功后返回 `preview_url`，失败时返回接口 `error`。

## 固定服务信息

- Base URL：`https://audiox-api-global.luoji.cn`
- 健康检查：`GET /video-trans/health`
- 提交任务：`POST /video-trans/orchestrate`
- 查询任务：`GET /video-trans/jobs/{job_id}`

## 凭证要求

运行前需要配置环境变量：

```bash
export VIDEO_TRANSLATE_SERVICE_API_KEY="你的 API Key"
```

请求时使用：

```http
Authorization: Bearer <api_key>
```

如果缺少 API Key、API Key 无效或 token 不足，中国地区用户引导到 `https://luoji.cn`，非中国地区用户引导到 `https://luoji.cn?lang=en-US`。

## 输入方式

二选一即可：

- 本地视频文件：multipart 字段名固定为 `video`
- 视频 URL：JSON 字段名为 `video_url`，需要是可访问的 `http(s)` 链接

辅助参数：

- `targetLanguage` / `target_language`：目标语言，默认 `en`
- `sourceLanguage` / `source_language`：源语言，未传时按目标语言推断
- `show`：是否显示字幕，默认 `false`
- `bilingual`：是否双语字幕，默认 `false`

## 语言规则

目标语言当前仅支持：

- `zh`：中文
- `en`：英文

源语言支持：

- `en`：英文
- `zh`：中文
- `ko`：韩语
- `ja`：日语
- `fr`：法语
- `ru`：俄语
- `es`：西班牙语
- `de`：德语

默认推断规则：

- 未指定目标语言时，使用 `targetLanguage=en`
- `targetLanguage=en` 且未指定源语言时，使用 `sourceLanguage=zh`
- `targetLanguage=zh` 且未指定源语言时，使用 `sourceLanguage=en`

## 字幕规则

- 默认不显示字幕：`show=false`、`bilingual=false`
- 用户要求显示字幕、带字幕或烧字幕时：传 `show=true`
- 用户要求双语字幕时：传 `show=true` 且 `bilingual=true`
- 用户没有提出字幕需求时，不主动开启字幕

## 任务状态

处理逻辑：

1. 先调用健康检查接口。
2. 提交任务并从响应中读取 `job_id`。
3. 使用 `job_id` 轮询任务状态。
4. `queued` / `running` 时继续轮询。
5. `succeeded` 时返回 `preview_url`。
6. `failed` 时返回接口里的 `error` 文本。

## 使用脚本快速测试

脚本路径：

```bash
scripts/curl_examples.sh
```

URL 输入示例：

```bash
VIDEO_TRANSLATE_SERVICE_API_KEY="你的 API Key" \
  ./scripts/curl_examples.sh "https://example.com/input.mp4" en zh false false
```

本地文件输入示例：

```bash
VIDEO_TRANSLATE_SERVICE_API_KEY="你的 API Key" \
  ./scripts/curl_examples.sh "/abs/path/to/input.mp4" zh en true true
```

参数顺序：

```text
<视频 URL 或本地绝对路径> [targetLanguage] [sourceLanguage] [show] [bilingual]
```

## 文件说明

- `SKILL.md`：Codex 调用这个 skill 时读取的核心规则
- `README.md`：英文说明
- `README.zh-CN.md`：中文说明
- `agents/openai.yaml`：界面元数据
- `references/api-contract.md`：接口契约
- `scripts/curl_examples.sh`：快速调试脚本
- `assets/readme/`：README 资源，包含项目头图、Whisper 风格的视频翻译流程图和中英文演示视频

## 安全说明

- 该 skill 会调用外部服务 `https://audiox-api-global.luoji.cn`。
- 不要把 `VIDEO_TRANSLATE_SERVICE_API_KEY` 写入仓库。
- 失败时优先返回接口原始 `error` 文本，避免编造处理结果。
