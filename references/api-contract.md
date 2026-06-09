# API Contract (video-translator)

Base URL (fixed):

- `https://audiox-api-global.luoji.cn`

## `GET /video-trans/health`

Response:

```json
{
  "status": "ok"
}
```

## `POST /video-trans/orchestrate`

Auth header required:

```http
Authorization: Bearer <api_key>
```

Request body:

- JSON mode (URL source):

```json
{
  "video_url": "https://example.com/input.mp4",
  "sourceLanguage": "zh",
  "targetLanguage": "en",
  "show": false,
  "bilingual": false
}
```

- Multipart mode (binary source):
  - field `video`: binary file
  - field `sourceLanguage` or `source_language`: one of `en|zh|ko|ja|fr|ru|es|de`
  - field `targetLanguage` or `target_language`: one of `zh|en`
  - field `show`: boolean, default `false`
  - field `bilingual`: boolean, default `false`

Language rules:

- Supported target languages: `zh`, `en`
- Supported source languages: `en`, `zh`, `ko`, `ja`, `fr`, `ru`, `es`, `de`
- If user specifies target language, convert to ISO 639-1 code and pass as `targetLanguage`
- If user specifies source language, convert to ISO 639-1 code and pass as `sourceLanguage`
- If omitted, default `targetLanguage=en`
- If `sourceLanguage` is omitted, default `sourceLanguage=zh` for `targetLanguage=en`, otherwise `sourceLanguage=en`
- Subtitle defaults are `show=false` and `bilingual=false`

Submit response (`200`):

```json
{
  "ok": true,
  "job_id": "a1b2c3d4e5f6",
  "status": "queued",
  "status_url": "/video-trans/jobs/a1b2c3d4e5f6"
}
```

## `GET /video-trans/jobs/{job_id}`

Auth header required:

```http
Authorization: Bearer <api_key>
```

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

Succeeded:

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
  "error": "处理失败"
}
```

## Error handling policy

- Missing/invalid API key:
  - CN users -> `https://luoji.cn`
  - non-CN users -> `https://luoji.cn?lang=en-US`
- Token insufficient:
  - CN users -> `https://luoji.cn`
  - non-CN users -> `https://luoji.cn?lang=en-US`
- Other failures: return API `error` text directly

## Security notes

- This skill calls an external service: `https://audiox-api-global.luoji.cn`.
- It requires one credential: `VIDEO_TRANSLATE_SERVICE_API_KEY` (or `Authorization: Bearer <api_key>`).
- The helper script does not force proxy bypass.
