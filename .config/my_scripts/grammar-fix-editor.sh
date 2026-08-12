#!/usr/bin/env bash
# grammar-fix-editor.sh — drop-in $EDITOR that grammar-corrects the file content
#
# Used by Claude Code (ctrl+g), AGY, and any tool that invokes $EDITOR on a
# temp file. Sends the draft to an LLM and overwrites the file with the
# corrected version — the calling tool picks up the clean text.
#
# Provider chain (first success wins):
#   1. Local llama-server  (GRAMMAR_FIX_URL, default http://localhost:8080)
#   2. DeepSeek Direct API (DEEPSEEK_API_KEY)
#   3. OpenRouter API      (OPENROUTER_API_KEY)
#
# All providers use the OpenAI /v1/chat/completions format.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

FILE="${1:?usage: grammar-fix-editor.sh <file>}"
[ -s "$FILE" ] || exit 0

# ── Config ────────────────────────────────────────────────────────────────────
LOCAL_URL="${GRAMMAR_FIX_URL:-http://localhost:8080}"
DEEPSEEK_URL="${GRAMMAR_FIX_DEEPSEEK_URL:-https://api.deepseek.com}"
DEEPSEEK_MODEL="${GRAMMAR_FIX_DEEPSEEK_MODEL:-deepseek-chat}"

OPENROUTER_URL="${GRAMMAR_FIX_OPENROUTER_URL:-https://openrouter.ai/api/v1}"
OPENROUTER_MODEL="${GRAMMAR_FIX_OPENROUTER_MODEL:-deepseek/deepseek-chat}"

TIMEOUT="${GRAMMAR_FIX_TIMEOUT:-20}"

SYSTEM_PROMPT='You are a grammar fixer for a coding-agent message input.
Fix ONLY grammar, spelling, punctuation, typos, and capitalization errors.
Rules:
- Do NOT translate technical terms (code, commands, git terms like commit/branch/merge/staging, framework names, APIs, jargon, file paths, URLs, identifiers, quoted strings) — keep them in their technical form even when the surrounding text is in another language.
- Do not change code, commands, file paths, URLs, identifiers, or quoted strings.
- Do not rewrite style, add, or remove content.
- Keep line breaks and overall structure.
- Reply with ONLY the corrected text. No explanations, no quotes, no preamble.'

ORIGINAL="$(<"$FILE")"

# ── Helpers ───────────────────────────────────────────────────────────────────

build_payload() {
  local model="$1"
  if [ -n "$model" ]; then
    jq -n --arg sys "$SYSTEM_PROMPT" --arg user "$ORIGINAL" --arg model "$model" \
      '{model: $model, messages: [{role: "system", content: $sys}, {role: "user", content: $user}], temperature: 0, max_tokens: 2048}'
  else
    jq -n --arg sys "$SYSTEM_PROMPT" --arg user "$ORIGINAL" \
      '{messages: [{role: "system", content: $sys}, {role: "user", content: $user}], temperature: 0, max_tokens: 2048}'
  fi
}

extract_content() {
  # Handles both regular (content) and reasoning (reasoning_content) responses,
  # then strips any <think>...</think> blocks left by reasoning models.
  local raw
  raw="$(jq -r '
    .choices[0].message |
    if   (.content // "") != "" then .content
    elif (.reasoning_content // "") != "" then .reasoning_content
    else empty
    end
  ' 2>/dev/null)"
  # Strip thinking tags (multiline, non-greedy)
  printf '%s' "$raw" | perl -0pe 's/<think>.*?<\/think>\s*//gs'
}

try_provider() {
  local endpoint="$1" auth_header="$2" model="$3" label="$4"
  local payload response corrected

  payload="$(build_payload "$model")"

  local curl_args=(-sf --max-time "$TIMEOUT" "$endpoint"
    -H "Content-Type: application/json"
    -d "$payload")

  [ -n "$auth_header" ] && curl_args+=(-H "$auth_header")

  response="$(curl "${curl_args[@]}" 2>/dev/null)" || return 1
  corrected="$(printf '%s' "$response" | extract_content)"

  [ -n "$corrected" ] || return 1

  printf '%s' "$corrected" > "$FILE"
  return 0
}

# ── Provider chain ────────────────────────────────────────────────────────────

# 1. Local llama-server (fast, free, no auth)
try_provider "$LOCAL_URL/v1/chat/completions" "" "" "local" && exit 0

# 2. DeepSeek Direct API (fallback)
DEEPSEEK_KEY="${DEEPSEEK_API_KEY:-${GRAMMAR_FIX_DEEPSEEK_KEY:-}}"
if [ -n "$DEEPSEEK_KEY" ]; then
  try_provider "$DEEPSEEK_URL/chat/completions" "Authorization: Bearer $DEEPSEEK_KEY" \
    "$DEEPSEEK_MODEL" "deepseek-direct" && exit 0
fi

# 3. OpenRouter API (secondary fallback)
OPENROUTER_KEY="${OPENROUTER_API_KEY:-}"
if [ -n "$OPENROUTER_KEY" ]; then
  try_provider "$OPENROUTER_URL/chat/completions" "Authorization: Bearer $OPENROUTER_KEY" \
    "$OPENROUTER_MODEL" "openrouter" && exit 0
fi

# All providers failed — leave file untouched
exit 0
