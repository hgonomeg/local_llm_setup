# LLM Development Stack

Local, GPU-accelerated LLM development environment using Docker.

**Ollama** serves models (Qwen 3.5, Qwen 3.6, Gemma 4) with NVIDIA GPU passthrough.
**Arch Linux** container provides a full dev toolchain + OpenCode agentic coding.

## Prerequisites

- Docker Engine with Compose V2
- NVIDIA drivers installed on host
- NVIDIA Container Toolkit (`nvidia-ctk`)
- ~80GB disk space for models

## Quick Start

```bash

# 0. Build the ollama host container
docker compose build ollama_palace

# 1. Start the Ollama server
docker compose up -d ollama_palace

# 2.1. Create configuration for the Searxng container (for web searches in the dev container)
sed "s|CHANGE_ME|$(openssl rand -hex 32)|" searxng_configs/settings.yml.template | grep -v sed | grep -v Generate > searxng_configs/settings.yml
# 2.2. Start the Searxng container (for web searches in the dev container)
docker compose up -d searxng_llm

# 2. Pull all models and create context-size variants (~80GB download)
docker exec ollama_palace bash /ollama_palace_init.sh

# 3. Build the dev image
docker compose build llm_dev

# 4. Spawn a dev container
docker compose run --rm -v `pwd`:/workspace llm_dev
docker compose run --rm -v /path/to/project:/workspace llm_dev

# Optionally you can also set up a nice web UI for Ollama
docker compose up -d open_webui
```

To your `.bashrc` / `.zshrc` add this:

```bash
### This lets you automate spawning llm dev contaniers in the current working directory available immediately at /workspace
function spawn_llm_dev_container_here() {
  HERE=`pwd`
  CONTAINER_NAME="$(echo $HERE | md5sum |  cut -d ' ' -f 1)_llm_dev"
  LOCAL_LLM_SETUP_REPO=/path/to/local_llm_setup # Replace this with your local path
  DOCKER_CMD="docker" # You may need to change that if you want `sudo`
  echo Container name: $CONTAINER_NAME
  if [ "$1" = "--persist" ]; then
    RM_FLAG=""
  else
    RM_FLAG="--rm"
  fi
  pushd $LOCAL_LLM_SETUP_REPO && (
    if $DOCKER_CMD container ls -a --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
      echo Using existent container
      if [ $($DOCKER_CMD container inspect $CONTAINER_NAME --format "{{.State.Status}}") != "running" ]; then
        echo Container is not running. Needs to be started.
        $DOCKER_CMD container start $CONTAINER_NAME
      fi
      $DOCKER_CMD exec -it $CONTAINER_NAME bash
    else
      echo Creating new container
      $DOCKER_CMD compose run $RM_FLAG --name $CONTAINER_NAME -it -v ${HERE}:/workspace llm_dev
    fi
  )
  popd
}

  
```

## Available Models

Each base model has 16K, 32K, 64K, and 128K context variants:

| Model | Type | Active Params | Download | Best for |
|-------|------|--------------|----------|----------|
| `qwen3.5-4b-*` | Dense | 4B | ? | Super-fast fallback |
| `qwen3.5-9b-*` | Dense | 9B | ~6GB | Fast fallback, fits in 8GB VRAM |
| `qwen3.5-27b-*` | Dense | 27B | ? | Agentic coding, tool use (better analysis; much slower) |
| `qwen3.5-35b-a3b-*` | MoE | 3B | ~24GB | Agentic coding, tool use |
| `qwen3.6-35b-a3b-*` | MoE | 3B | ? | Agentic coding, tool use |
| `gemma4-26b-*` | MoE | 3.8B | ~18GB | Pure coding, multilingual |
| `gemma4-e4b-*` | Dense | 4.5B | ~6GB | Ultra-fast, fits in 8GB VRAM |
| `qemma4-31b-*` | Dense | 31B | ? | Agentic coding, tool use (better analysis; much slower) |


## Day-to-Day Usage

```bash
# Start Ollama (if not running)
docker compose up -d ollama_palace

# Spawn a fresh dev shell
docker compose run --rm -v /path/to/project:/workspace llm_dev

# Inside the container:
opencode                    # Launch OpenCode agent
models                      # List all available models
ollama-ps                   # Show loaded models + GPU usage
ollama-test gemma4-26b-64k  # Benchmark a model

```


## Volumes

| Volume | Purpose | Persists across |
|--------|---------|----------------|
| `ollama_data` | Model weights (~80GB) | Container restarts, rebuilds |

## Tips

- **Model too slow?** Drop to a smaller context: `qwen3.5-35b-a3b-32k` instead of `128k`
- **VRAM full?** Use `gemma4-e4b-*` or `qwen3.5-9b-*` — they fit entirely in 8GB
- **OpenCode tools not working?** Ensure model has `"tools": true` in config and context >= 32K
