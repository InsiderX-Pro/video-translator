#!/usr/bin/env bash
# Quick end-to-end check of the video translation API:
#   health -> submit (file or URL) -> poll -> preview_url
#
# Usage:
#   VIDEO_TRANSLATE_SERVICE_API_KEY=sk_... ./curl_examples.sh <video-url | /abs/path.mp4> \
#       [targetLanguage] [sourceLanguage] [show] [bilingual] [model]
#
#   model: podcast (default, 播客直译) | pro (AI 视频直译 Pro) | normal (AI 视频直译)
#   podcast: target zh|en; target en needs source zh; target zh needs source en|ko|ja|fr|ru|es|de
#   pro/normal: source zh|ko|ja|en; target zh|ko|en|fr|es|th|vi|lo
set -euo pipefail

BASE_URL="https://audiox-api-global.luoji.cn"
API_KEY="${VIDEO_TRANSLATE_SERVICE_API_KEY:-}"

if [[ -z "${API_KEY}" ]]; then
  echo "missing env VIDEO_TRANSLATE_SERVICE_API_KEY"
  echo "create one at https://luoji.cn/studio/api-keys (non-CN: https://luoji.cn/studio/api-keys?lang=en-US)"
  exit 1
fi

normalize_language() {
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
    th|thai|th-th|泰语|泰文) echo "th" ;;
    vi|vietnamese|vi-vn|越南语|越语) echo "vi" ;;
    lo|lao|lo-la|老挝语|老挝文) echo "lo" ;;
    *) return 1 ;;
  esac
}

normalize_model() {
  local raw
  raw="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr '-' '_')"
  case "$raw" in
    ""|podcast|podcast_out|播客直译) echo "podcast" ;;
    pro|video_translate_pro) echo "pro" ;;
    normal|video_translate_normal) echo "normal" ;;
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

in_list() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

if [[ "${1:-}" == "" ]]; then
  echo "Usage: $0 <http(s)-video-url | /abs/path/to/input.mp4> [targetLanguage] [sourceLanguage] [show] [bilingual] [model]"
  echo "model: podcast (default) | pro | normal"
  echo "podcast: targetLanguage zh|en (default en); target en -> source zh; target zh -> source en|ko|ja|fr|ru|es|de"
  echo "pro/normal: sourceLanguage zh|ko|ja|en (default zh); targetLanguage zh|ko|en|fr|es|th|vi|lo (default en)"
  echo "show/bilingual: true|false (default false false)"
  exit 1
fi

VIDEO_SOURCE="$1"
RAW_TARGET_LANGUAGE="${2:-en}"
RAW_SOURCE_LANGUAGE="${3:-}"
SHOW="$(normalize_bool "${4:-false}" "show")"
BILINGUAL="$(normalize_bool "${5:-false}" "bilingual")"
RAW_MODEL="${6:-podcast}"

if ! MODEL="$(normalize_model "${RAW_MODEL}")"; then
  echo "unsupported model: ${RAW_MODEL} (use podcast, pro or normal)"
  exit 1
fi
if ! TARGET_LANGUAGE="$(normalize_language "${RAW_TARGET_LANGUAGE}")"; then
  echo "unsupported target language: ${RAW_TARGET_LANGUAGE}"
  exit 1
fi

if [[ "${MODEL}" == "podcast" ]]; then
  if ! in_list "${TARGET_LANGUAGE}" zh en; then
    echo "model podcast supports targetLanguage zh or en only (got ${TARGET_LANGUAGE}); use model normal for ${TARGET_LANGUAGE}"
    exit 1
  fi
  if [[ "${TARGET_LANGUAGE}" == "en" ]]; then
    ALLOWED_SOURCES=(zh)
    DEFAULT_SOURCE="zh"
  else
    ALLOWED_SOURCES=(en ko ja fr ru es de)
    DEFAULT_SOURCE="en"
  fi
else
  if ! in_list "${TARGET_LANGUAGE}" zh ko en fr es th vi lo; then
    echo "model ${MODEL} supports targetLanguage zh ko en fr es th vi lo (got ${TARGET_LANGUAGE})"
    exit 1
  fi
  ALLOWED_SOURCES=(zh ko ja en)
  DEFAULT_SOURCE="zh"
fi

if [[ -n "${RAW_SOURCE_LANGUAGE}" ]]; then
  if ! SOURCE_LANGUAGE="$(normalize_language "${RAW_SOURCE_LANGUAGE}")"; then
    echo "unsupported source language: ${RAW_SOURCE_LANGUAGE}"
    exit 1
  fi
  if ! in_list "${SOURCE_LANGUAGE}" "${ALLOWED_SOURCES[@]}"; then
    echo "model ${MODEL} with targetLanguage ${TARGET_LANGUAGE} supports sourceLanguage: ${ALLOWED_SOURCES[*]} (got ${SOURCE_LANGUAGE})"
    exit 1
  fi
else
  SOURCE_LANGUAGE="${DEFAULT_SOURCE}"
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
  "model": "${MODEL}",
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
    -F "model=${MODEL}" \
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
echo "  model=${MODEL}"
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
echo "${STATUS_RESP}" | sed 's/.*/  &/'
