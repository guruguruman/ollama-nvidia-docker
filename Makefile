SHELL := /bin/bash
COMPOSE := docker compose
SERVICE := ollama

MODEL ?= gpt-oss:20b
BASE_URL ?= http://localhost:11434/v1
TEMP ?= 0.7
TOP_K ?= 0
TOP_P ?= 1.0
MAX_TOKENS ?= 512
STREAM ?= false
TIMEOUT ?= 120

JSON := application/json
AUTH := "Authorization: Bearer ANY"
CURL := curl -sS --max-time $(TIMEOUT)
JQ ?= jq

.PHONY: help
help:
	@awk 'BEGIN{FS=":.*## "; printf "\nOllama Make targets:\n\n"} /^[a-zA-Z0-9_%-]+:.*## /{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST); \
	echo; echo "Defaults:"; \
	echo "  MODEL=$(MODEL)"; echo "  BASE_URL=$(BASE_URL)"; echo

# ========== Docker containers ==========
.PHONY: up down restart ps logs sh
up: ## Start containers (creates ./data/* on first run)
	@mkdir -p ./data/models ./data/cache
	$(COMPOSE) up -d

down: ## Stop and remove containers
	$(COMPOSE) down

restart: ## Recreate containers
	$(COMPOSE) down && $(COMPOSE) up -d

ps: ## Container status
	$(COMPOSE) ps

logs: ## Tail logs
	$(COMPOSE) logs -f $(SERVICE)

sh: ## Shell into service
	$(COMPOSE) exec $(SERVICE) bash

# ========== GPU / Disk ==========
.PHONY: smi size du-cache
smi: ## GPU usage (nvidia-smi)
	$(COMPOSE) exec $(SERVICE) bash -lc 'nvidia-smi || true'

size: ## Total model size
	@du -sh ./data/models || true

du-cache: ## Total cache size
	@du -sh ./data/cache || true

# ========== Ollama CLI ==========
.PHONY: pull list rm rm-all show
pull: ## Pull model: make pull MODEL=name:tag
	@if [ -z "$(MODEL)" ]; then echo "Usage: make pull MODEL=<name:tag>"; exit 1; fi
	$(COMPOSE) exec $(SERVICE) ollama pull $(MODEL)

list: ## List models
	$(COMPOSE) exec $(SERVICE) ollama list

rm: ## Remove model: make rm MODEL=name:tag
	@if [ -z "$(MODEL)" ]; then echo "Usage: make rm MODEL=<name:tag>"; exit 1; fi
	$(COMPOSE) exec $(SERVICE) ollama rm $(MODEL)

rm-all: ## Remove all models (confirmation)
	@read -p "Remove ALL models under ./data/models ? [y/N] " a; [ "$$a" = "y" ] || [ "$$a" = "Y" ]
	$(COMPOSE) exec $(SERVICE) bash -lc 'ollama list | awk "NR>1{print \$$1}" | xargs -r -n1 ollama rm'
	@echo "Done."

show: ## Show model info (JSON): make show MODEL=name:tag
	@if [ -z "$(MODEL)" ]; then echo "Usage: make show MODEL=<name:tag>"; exit 1; fi
	$(COMPOSE) exec $(SERVICE) ollama show $(MODEL)

.PHONY: models health
models: ## GET /v1/models
	$(CURL) $(BASE_URL)/models | $(JQ) .

health: ## Health check via /v1/models (exit code only)
	@$(CURL) -o /dev/null -w "%{http_code}\n" $(BASE_URL)/models | grep -Eq "200|401"
