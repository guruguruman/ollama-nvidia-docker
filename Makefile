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

.PHONY: up down restart ps logs sh
up: ## コンテナ起動（初回はdata配下を自動作成）
	@mkdir -p ./data/models ./data/cache
	$(COMPOSE) up -d

down: ## コンテナ停止・削除
	$(COMPOSE) down

restart: ## 再起動
	$(COMPOSE) down && $(COMPOSE) up -d

ps: ## コンテナ状況
	$(COMPOSE) ps

logs: ## ログ追跡
	$(COMPOSE) logs -f $(SERVICE)

sh: ## シェル突入
	$(COMPOSE) exec $(SERVICE) bash

# ========== GPU / ディスク確認 ==========
.PHONY: smi size du-cache
smi: ## GPU利用状況(nvidia-smi)
	$(COMPOSE) exec $(SERVICE) bash -lc 'nvidia-smi || true'

size: ## モデルサイズ合計
	@du -sh ./data/models || true

du-cache: ## キャッシュサイズ合計
	@du -sh ./data/cache || true

# ========== Ollama基本操作 ==========
.PHONY: pull list rm rm-all show run prompt
pull: ## モデル取得: make pull MODEL=name:tag
	@if [ -z "$(MODEL)" ]; then echo "Usage: make pull MODEL=<name:tag>"; exit 1; fi
	$(COMPOSE) exec $(SERVICE) ollama pull $(MODEL)

list: ## モデル一覧
	$(COMPOSE) exec $(SERVICE) ollama list

rm: ## モデル削除: make rm MODEL=name:tag
	@if [ -z "$(MODEL)" ]; then echo "Usage: make rm MODEL=<name:tag>"; exit 1; fi
	$(COMPOSE) exec $(SERVICE) ollama rm $(MODEL)

rm-all: ## すべてのモデル削除(要確認)
	@read -p "Remove ALL models under ./data/models ? [y/N] " a; [ "$$a" = "y" ] || [ "$$a" = "Y" ]
	$(COMPOSE) exec $(SERVICE) bash -lc 'ollama list | awk "NR>1{print \$$1}" | xargs -r -n1 ollama rm'
	@echo "Done."

show: ## モデル情報(JSON): make show MODEL=name:tag
	@if [ -z "$(MODEL)" ]; then echo "Usage: make show MODEL=<name:tag>"; exit 1; fi
	$(COMPOSE) exec $(SERVICE) ollama show $(MODEL)

.PHONY: models health
models: ## /v1/models 取得
	$(CURL) $(BASE_URL)/models | $(JQ) .

health: ## /v1/modelsで疎通確認(終了コードのみ)
	@$(CURL) -o /dev/null -w "%{http_code}\n" $(BASE_URL)/models | grep -Eq "200|401"
