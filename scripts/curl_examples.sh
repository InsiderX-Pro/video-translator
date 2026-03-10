#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://audiox-api-global.luoji.cn"
API_KEY="${VIDEO_TRANSLATE_SERVICE_API_KEY:-}"

if [[ -z "${API_KEY}" ]]; then
  echo "missing env VIDEO_TRANSLATE_SERVICE_API_KEY"
  echo "please handle API key at https://luoji.cn (non-CN: https://luoji.cn?lang=en-US)"
  exit 1
fi

if [[ "${1:-}" == "" ]]; then
  echo "Usage: $0 <http(s)-video-url | /abs/path/to/input.mp4> [target_language]"
  echo "target_language supports: zh en fr ja (default: en)"
  exit 1
fi

VIDEO_SOURCE="$1"
RAW_LANG="${2:-en}"

normalize_lang() {
  local raw
  raw="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    zh|chinese|cn|zh-cn|中文) echo "zh" ;;
    en|english|en-us|英语|英文) echo "en" ;;
    fr|french|français|francais|法语|法文) echo "fr" ;;
    ja|japanese|jp|ja-jp|日语|日文|日本語) echo "ja" ;;
    *) echo "" ;;
  esac
}

TARGET_LANGUAGE="$(normalize_lang "${RAW_LANG}")"
if [[ -z "${TARGET_LANGUAGE}" ]]; then
  echo "unsupported target language: ${RAW_LANG}"
  echo "supported: zh en fr ja"
  exit 1
fi

echo "[1/4] Health check: ${BASE_URL}/video-trans/health"
curl -sS "${BASE_URL}/video-trans/health" | sed 's/.*/  &/'

echo "[2/4] Submit job"
if [[ "${VIDEO_SOURCE}" =~ ^https?:// ]]; then
  SUBMIT_RESP="$(curl -sS -X POST "${BASE_URL}/video-trans/orchestrate" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H 'Content-Type: application/json' \
    --data-binary @- <<JSON
{
  "video_url": "${VIDEO_SOURCE}",
  "target_language": "${TARGET_LANGUAGE}"
}
JSON
)"
else
  if [[ ! -f "${VIDEO_SOURCE}" ]]; then
    echo "local file not found: ${VIDEO_SOURCE}"
    exit 1
  fi
  SUBMIT_RESP="$(curl -sS -X POST "${BASE_URL}/video-trans/orchestrate" \
    -H "Authorization: Bearer ${API_KEY}" \
    -F "video=@${VIDEO_SOURCE}" \
    -F "target_language=${TARGET_LANGUAGE}")"
fi

echo "${SUBMIT_RESP}" | sed 's/.*/  &/'
JOB_ID="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("job_id",""))' <<< "${SUBMIT_RESP}")"
if [[ -z "${JOB_ID}" ]]; then
  echo "submit failed"
  exit 1
fi

echo "[3/4] Poll: ${JOB_ID}"
echo "  target_language=${TARGET_LANGUAGE}"
while true; do
  STATUS_RESP="$(curl -sS -H "Authorization: Bearer ${API_KEY}" "${BASE_URL}/video-trans/jobs/${JOB_ID}")"
  STATUS="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("status",""))' <<< "${STATUS_RESP}")"
  echo "  status=${STATUS}"
  if [[ "${STATUS}" == "succeeded" || "${STATUS}" == "failed" ]]; then
    break
  fi
  sleep 3
done

echo "[4/4] Final"
FINAL_RESP="$(curl -sS -H "Authorization: Bearer ${API_KEY}" "${BASE_URL}/video-trans/jobs/${JOB_ID}")"
echo "${FINAL_RESP}"
