#!/usr/bin/make -f

.ONESHELL:
.PHONY: build clean
.DEFAULT_GOAL := help
.SHELL := /usr/bin/bash

ifndef $(GOROOT)
    GOROOT=$(shell go env GOROOT)
    export GOROOT
endif

help:
	@echo "Usage: make [options] [arguments]\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

define env_setup
	$(eval ENV_FILE := $(1).env)
	@echo " - setup env $(ENV_FILE)"
	$(eval include $(1).env)
	$(eval export sed 's/=.*//' $(1).env)
	$(eval export ENV_FILE)
endef

env-check: ## must be used along with the load of the environment
	$(eval VARS=$(shell sh -c "cat $(ENV_FILE)"))

	@IS_ANY_UNSET=false; \
	for key in $(VARS); do \
		[ -z "$${key#*=}" ] && echo "env: $$key is not set" && IS_ANY_UNSET=true; \
	done; \
	if [ "$$IS_ANY_UNSET" = true ]; then echo "Aborting"; exit 1; else echo "env: using $$ENV_FILE"; fi

env-production: ## Load production.env environment
	$(call env_setup,production)

build: env-check  ## Build the current project
	@if [[ ! -f ./wasm_exec.js ]]; then \
		rm -rf .cache dist; \
		go get github.com/golang/go/misc; \
		cp "${GOROOT}/misc/wasm/wasm_exec.js" .; \
		npm install; \
		npm run build; \
		cp ./metadata.json dist/metadata.json; \
	fi

	$(eval export GOOS=js)
	$(eval export GOARCH=wasm)
	go build -o dist/go.wasm main.go

# https://api.cloudflare.com/#worker-script-upload-worker
deploy-with-token: env-check
	@curl -X PUT \
		"https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/workers/scripts/${CF_WORKER_NAME}" \
		-H "Authorization: Bearer ${CF_API_TOKEN}" \
		-F "metadata=@dist/metadata.json;type=application/json" \
		-F "script=@dist/worker.js;type=application/javascript" \
		-F "wasm=@dist/go.wasm;type=application/wasm" # > /dev/null # the response is too verbose

deploy-global-key: env-check
	@curl -X PUT \
		"https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/workers/scripts/${CF_WORKER_NAME}" \
		-H "X-Auth-Email: ${CF_USER_EMAIL}" \
     	-H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
		-F "metadata=@dist/metadata.json;type=application/json" \
		-F "script=@dist/worker.js;type=application/javascript" \
		-F "wasm=@dist/go.wasm;type=application/wasm" # > /dev/null # the response is too verbose

clean:
	rm -rf .parcel-cache dist node_modules package-lock.json wasm_exec.js
