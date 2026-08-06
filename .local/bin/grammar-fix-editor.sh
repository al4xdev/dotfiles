#!/usr/bin/env bash
# grammar-fix-editor.sh — acts as $EDITOR for Claude Code's chat:externalEditor
# (default ctrl+g). Fixes grammar of the message via a local llama-server
# instance (http://localhost:8080, OpenAI-compatible API) instead of opening
# a real editor. Mirrors al4xdev/pi-grammar-fix's correction rules.
set -euo pipefail

LLAMA_URL="${GRAMMAR_FIX_URL:-http://localhost:8080}"
FILE="$1"

[ -s "$FILE" ] || exit 0

SYSTEM_PROMPT='You are a grammar fixer for a coding-agent message input.
Fix ONLY grammar, spelling, punctuation, typos, and capitalization errors.
Rules:
- Do NOT translate technical terms (code, commands, git terms like commit/branch/merge/staging, framework names, APIs, jargon, file paths, URLs, identifiers, quoted strings) — keep them in their technical form even when the surrounding text is in another language.
- Do not change code, commands, file paths, URLs, identifiers, or quoted strings.
- Do not rewrite style, add, or remove content.
- Keep line breaks and overall structure.
- Reply with ONLY the corrected text. No explanations, no quotes, no preamble.'

ORIGINAL="$(cat "$FILE")"

PAYLOAD="$(jq -n --arg sys "$SYSTEM_PROMPT" --arg user "$ORIGINAL" \
  '{messages: [{role: "system", content: $sys}, {role: "user", content: $user}], temperature: 0, max_tokens: 2048}')"

RESPONSE="$(curl -sf --max-time 20 "$LLAMA_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")" || { exit 0; }

CORRECTED="$(printf '%s' "$RESPONSE" | jq -r '.choices[0].message.content // empty')"

if [ -n "$CORRECTED" ]; then
  printf '%s' "$CORRECTED" > "$FILE"
fi
