#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://audiox-api-global.luoji.cn"
API_KEY="${VIDEO_TRANSLATE_SERVICE_API_KEY:-}"

if [[ -z "${API_KEY}" ]]; then
  echo "missing env VIDEO_TRANSLATE_SERVICE_API_KEY"
  echo "please handle API key at https://luoji.cn (non-CN: https://luoji.cn?lang=en-US)"
  exit 1
fi

normalize_target_language() {
  local raw
  raw="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
  case "$raw" in
    zh|chinese|cn|zh-cn|zh-hans|中文) echo "zh" ;;
    en|english|en-us|en-gb|英语|英文) echo "en" ;;
    *) return 1 ;;
  esac
}

normalize_source_language() {
  local raw
  raw="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
  case "$raw" in
    zh|chinese|cn|zh-cn|zh-hans|中文) echo "zh" ;;
    en|english|en-us|en-gb|英语|英文) echo "en" ;;
    ko|korean|kr|ko-kr|韩语|韩文|한국어) echo "ko" ;;
    ja|japanese|jp|ja-jp|日语|日文|日本語) echo "ja" ;;
    fr|french|fr-fr|français|francais|法语|法文) echo "fr" ;;
    ru|russian|ru-ru|俄语|俄文) echo "ru" ;;
    es|spanish|es-es|es-mx|西班牙语|西语) echo "es" ;;
    de|german|de-de|德语|德文) echo "de" ;;
    *) return 1 ;;
  esac
}

normalize_bool() {
  local value="$1"
  local label="$2"
  local raw
  raw="$(echo "${value}" | tr '[:upper:]' '[:lower:]')"
  case "${raw}" in
    true|1|yes|y|on|是|显示) echo "true" ;;
    false|0|no|n|off|否|不显示) echo "false" ;;
    *)
      echo "invalid ${label}: ${value} (use true or false)" >&2
      return 1
      ;;
  esac
}

if [[ "${1:-}" == "" ]]; then
  echo "Usage: $0 <http(s)-video-url | /abs/path/to/input.mp4> [targetLanguage] [sourceLanguage] [show] [bilingual]"
  echo "targetLanguage supports: zh en (default: en)"
  echo "sourceLanguage supports: en zh ko ja fr ru es de (default: zh when target=en, en when target=zh)"
  echo "show/bilingual support: true false (default: false false)"
  exit 1
fi

VIDEO_SOURCE="$1"
RAW_TARGET_LANGUAGE="${2:-en}"
RAW_SOURCE_LANGUAGE="${3:-}"
SHOW="$(normalize_bool "${4:-false}" "show")"
BILINGUAL="$(normalize_bool "${5:-false}" "bilingual")"

if ! TARGET_LANGUAGE="$(normalize_target_language "${RAW_TARGET_LANGUAGE}")"; then
  echo "unsupported target language: ${RAW_TARGET_LANGUAGE}"
  echo "supported: zh en"
  exit 1
fi

if [[ -n "${RAW_SOURCE_LANGUAGE}" ]]; then
  if ! SOURCE_LANGUAGE="$(normalize_source_language "${RAW_SOURCE_LANGUAGE}")"; then
    echo "unsupported source language: ${RAW_SOURCE_LANGUAGE}"
    echo "supported: en zh ko ja fr ru es de"
    exit 1
  fi
elif [[ "${TARGET_LANGUAGE}" == "zh" ]]; then
  SOURCE_LANGUAGE="en"
else
  SOURCE_LANGUAGE="zh"
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
  "sourceLanguage": "${SOURCE_LANGUAGE}",
  "targetLanguage": "${TARGET_LANGUAGE}",
  "show": ${SHOW},
  "bilingual": ${BILINGUAL}
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
    -F "sourceLanguage=${SOURCE_LANGUAGE}" \
    -F "targetLanguage=${TARGET_LANGUAGE}" \
    -F "show=${SHOW}" \
    -F "bilingual=${BILINGUAL}")"
fi

echo "${SUBMIT_RESP}" | sed 's/.*/  &/'
JOB_ID="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("job_id",""))' <<< "${SUBMIT_RESP}")"
if [[ -z "${JOB_ID}" ]]; then
  echo "submit failed"
  exit 1
fi

echo "[3/4] Poll: ${JOB_ID}"
echo "  sourceLanguage=${SOURCE_LANGUAGE}"
echo "  targetLanguage=${TARGET_LANGUAGE}"
echo "  show=${SHOW}"
echo "  bilingual=${BILINGUAL}"
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
