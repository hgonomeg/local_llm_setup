#!/usr/bin/env bash
set -euo pipefail
 
CONFIG="${HOME}/.config/opencode/opencode.json"

if [ -f "${HOME}/.config/opencode/opencode.json.generated" ]; then
  echo "▸ Config population script has already been run."
  exit 0
fi

echo "▸ Running single-time population of opencode.json"
 
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required" >&2
  exit 1
fi
 
if [ ! -f "$CONFIG" ]; then
  echo "Error: config not found at ${CONFIG}" >&2
  exit 1
fi
 
echo "▸ Querying ${OLLAMA_HOST}/api/tags ..."
 
MODELS_JSON=$(curl -sf "${OLLAMA_HOST}/api/tags" 2>/dev/null) || {
  echo "Error: cannot reach Ollama at ${OLLAMA_HOST}" >&2
  exit 1
}
 
# Build the new models object: each model name becomes a key with name + tools: true
# Filters out models whose name does not end with [0-9]k
NEW_MODELS=$(echo "$MODELS_JSON" | jq '
  [.models[].name] |
  map(select(test("[0-9]k$"))) |
  sort |
  reduce .[] as $m ({}; . + {($m): {name: $m, tools: true}})
')
 
COUNT=$(echo "$NEW_MODELS" | jq 'length')
echo "▸ Found ${COUNT} models"
 
# Update the config file in place
UPDATED=$(jq --argjson models "$NEW_MODELS" '
  .provider.ollama.models = $models
' "$CONFIG")
 
echo "$UPDATED" > "$CONFIG"
 
echo "▸ Updated ${CONFIG}"
echo ""
echo "$NEW_MODELS" | jq -r 'keys[]' | sed 's/^/  /'

touch "${HOME}/.config/opencode/opencode.json.generated"