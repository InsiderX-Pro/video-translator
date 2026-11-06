# API Contract (video-translator)

Base URL (fixed):

- `https://audiox-api-global.luoji.cn`

Auth header (every endpoint except health):

```http
Authorization: Bearer <api_key>
```

Keys are created at `https://luoji.cn/studio/api-keys`.

## `GET /video-trans/health`

Response:

```json
{
  "status": "ok"
}
```

## `POST /video-trans/orchestrate`

Request body:

- JSON mode (URL source):

```json
{
  "video_url": "https://example.com/input.mp4",
  "model": "podcast",
  "sourceLanguage": "zh",
  "targetLanguage": "en",
  "show": false,
  "bilingual": false
}
```

- Multipart mode (binary source):
  - field `video`: binary file
  - field `model`: `podcast` (default) | `pro` | `normal`
  - field `sourceLanguage` or `source_language`: see language rules
  - field `targetLanguage` or `target_language`: see language rules
  - field `show`: boolean, default `false`
  - field `bilingual`: boolean, default `false`

Models:

| `model` | Product | Pipeline |
| --- | --- | --- |
| `podcast` (default) | 播客直译 | dubbing → deep optimization preview → export |
| `pro` | AI 视频直译 Pro (keeps the original timbre) | dubbing → export |
| `normal` | AI 视频直译 (similar voice) | dubbing → export |

Language rules (ISO 639-1 codes; the server validates them and returns `400` with the allowed set otherwise):

- `model=podcast`
  - `targetLanguage`: `zh` or `en` (default `en`)
  - `targetLanguage=en` requires `sourceLanguage=zh` (default)
  - `targetLanguage=zh` requires `sourceLanguage` in `en|ko|ja|fr|ru|es|de` (default `en`)
- `model=pro` / `model=normal`
  - `sourceLanguage`: `zh|ko|ja|en` (default `zh`)
  - `targetLanguage`: `zh|ko|en|fr|es|th|vi|lo` (default `en`)
  - same source and target is allowed (re-dub only)
  - the video must be `mp4`, `mov`, `webm` or `mkv`

Subtitle defaults are `show=false` and `bilingual=false`.

Input limits enforced by the service: 300 MB and 5 minutes per video.

Submit response (`200`):

```json
{
  "ok": true,
  "job_id": "a1b2c3d4e5f6",
  "status": "queued",
  "status_url": "/video-trans/jobs/a1b2c3d4e5f6"
}
```

Validation failure (`400`):

```json
{
  "detail": "invalid request: ... sourceLanguage must be one of zh for model podcast with targetLanguage en"
}
```

## `GET /video-trans/jobs/{job_id}`

Response examples (`200`):

Processing:

```json
{
  "ok": true,
  "job_id": "a1b2c3d4e5f6",
  "status": "running",
  "preview_url": null,
  "error": null
}
```

Succeeded (`preview_url` is a signed link that expires; download it promptly):

```json
{
  "ok": true,
  "job_id": "a1b2c3d4e5f6",
  "status": "succeeded",
  "preview_url": "https://...",
  "error": null
}
```

Failed:

```json
{
  "ok": false,
  "job_id": "a1b2c3d4e5f6",
  "status": "failed",
  "preview_url": null,
  "error": "INSUFFICIENT_BALANCE"
}
```

`error` values worth handling: `INSUFFICIENT_BALANCE` (credits ran out), validation messages from
job creation, network errors; anything else is reported as `处理失败`.

## `GET /video-trans/jobs?page=0&page_size=20`

History of the caller's jobs (`job_id`, `status`, `created_at`, `preview_url`, `error`,
`source_file_name`, `target_language`, `model`).

## Billing

Jobs are billed in AudioX credits (积分) from the account that owns the API key:
`podcast` at the 播客直译 rate, `pro` / `normal` at their model rates. Balance and top-up:
`https://luoji.cn/studio/wallet`.

## Error handling policy

- Missing/invalid API key:
  - CN users -> `https://luoji.cn/studio/api-keys`
  - non-CN users -> `https://luoji.cn/studio/api-keys?lang=en-US`
- Credits insufficient (`INSUFFICIENT_BALANCE`):
  - CN users -> `https://luoji.cn/studio/wallet`
  - non-CN users -> `https://luoji.cn/studio/wallet?lang=en-US`
- Other failures: return API `error` text directly

## Security notes

- This skill calls an external service: `https://audiox-api-global.luoji.cn`.
- It requires one credential: `VIDEO_TRANSLATE_SERVICE_API_KEY` (or `Authorization: Bearer <api_key>`).
- The helper script does not force proxy bypass.
