#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ollama_palace_init.sh
# Pulls base models and creates context-size variants using Ollama Modelfiles.
# Runs inside the ollama_palace_init container, talks to the ollama server.
# ============================================================================

OLLAMA="ollama"

echo "============================================="
echo " Ollama Model Initialization"
echo " Server: ${OLLAMA_HOST}"
echo "============================================="

# ── 1. Pull base models ─────────────────────────────────────────────────────

BASE_MODELS=(
  "qwen3.5:4b"
  "qwen3.5:9b"
  "qwen3.5:27b"
  "qwen3.5:35b-a3b"
  "qwen3.6:35b-a3b"
  "gemma4:26b"
  "gemma4:e4b"
  "gemma4:31b"
)

declare -A CTX_SIZES=(
 [16k]=16384
 [32k]=32768
 [64k]=65536
 [128k]=131072
 [256k]=262144
)

for model in "${BASE_MODELS[@]}"; do
  echo ""
  echo "▸ Pulling ${model} ..."
  $OLLAMA pull "$model"
done

EMBEDDING_MODELS=(
  "qwen3-embedding:4b"
  "qwen3-embedding:8b"

)

echo "▸ Additionally, pulling embedding models..."

for emb_model in "${EMBEDDING_MODELS[@]}"; do
  echo ""
  echo "▸ Pulling embdedding model: ${emb_model} ..."
  $OLLAMA pull "$emb_model"
done

# ── 2. Create context-size variants from Modelfiles ─────────────────────────
echo ""
echo "▸ Creating context-size variants ..."
cd /tmp
mkdir -p modelfiles

for ctx_size in "${!CTX_SIZES[@]}"; do
  for model in "${BASE_MODELS[@]}"; do
    mf="modelfiles/${model}-${ctx_size}.Modelfile"
    printf 'FROM %s\nPARAMETER num_ctx %s\n' "$model" "${CTX_SIZES[$ctx_size]}" > "$mf"
    echo "▸ Written ${mf}"
  done
done

for mf in ./modelfiles/*.Modelfile; do
  name="$(basename "$mf" .Modelfile)"
  echo "  ▸ Creating ${name} from ${mf}"
  $OLLAMA create "$name" -f "$mf"
done

cd /
rm -rfv /tmp/modelfiles

# ── 3. List everything ──────────────────────────────────────────────────────
echo ""
echo "============================================="
echo " Installed models:"
echo "============================================="
$OLLAMA list

echo ""
echo "✓ All models ready."
