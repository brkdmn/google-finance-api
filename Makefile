SHELL := /bin/sh

APP_NAME ?= google-finance-api
CMD ?= ./cmd/server
BIN_DIR ?= bin
BIN ?= $(BIN_DIR)/$(APP_NAME)
PORT ?= 8080
BASE_URL ?= http://localhost:$(PORT)
VERSION := $(shell cat VERSION 2>/dev/null || echo dev)
GO ?= go
DOCKER ?= docker
DOCKER_COMPOSE ?= docker compose

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: run
run: ## Run the API locally without Docker
	PORT=$(PORT) $(GO) run $(CMD)

.PHONY: dev
dev: run ## Alias for local development

.PHONY: build
build: ## Build the local binary into bin/
	@mkdir -p $(BIN_DIR)
	$(GO) build -o $(BIN) $(CMD)

.PHONY: start
start: build ## Build and run the local binary
	PORT=$(PORT) ./$(BIN)

.PHONY: install
install: ## Install the server binary into GOPATH/bin
	$(GO) install $(CMD)

.PHONY: test
test: ## Run tests
	$(GO) test ./...

.PHONY: test-race
test-race: ## Run tests with race detector
	$(GO) test -race ./...

.PHONY: cover
cover: ## Generate an HTML coverage report
	$(GO) test -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html

.PHONY: fmt
fmt: ## Format Go source
	$(GO) fmt ./...

.PHONY: vet
vet: ## Run go vet
	$(GO) vet ./...

.PHONY: tidy
tidy: ## Tidy module files
	$(GO) mod tidy

.PHONY: check
check: fmt vet test ## Run format, vet, and tests

.PHONY: clean
clean: ## Remove generated local artifacts
	rm -rf $(BIN_DIR) coverage.out coverage.html

.PHONY: health
health: ## Check the local health endpoint
	curl -fsS $(BASE_URL)/healthz

.PHONY: docker-build
docker-build: ## Build the Docker image
	$(DOCKER) build -t $(APP_NAME):$(VERSION) -t $(APP_NAME):latest .

.PHONY: docker-up
docker-up: ## Start with Docker Compose
	PORT=$(PORT) $(DOCKER_COMPOSE) up -d --build

.PHONY: docker-down
docker-down: ## Stop Docker Compose services
	$(DOCKER_COMPOSE) down

.PHONY: docker-logs
docker-logs: ## Follow Docker Compose logs
	$(DOCKER_COMPOSE) logs -f

.PHONY: docker-restart
docker-restart: docker-down docker-up ## Restart Docker Compose services

.PHONY: release-linux
release-linux: ## Build a stripped Linux amd64 binary
	@mkdir -p $(BIN_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GO) build -ldflags="-s -w" -o $(BIN)-linux-amd64 $(CMD)

.PHONY: release-darwin
release-darwin: ## Build a stripped macOS arm64 binary
	@mkdir -p $(BIN_DIR)
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 $(GO) build -ldflags="-s -w" -o $(BIN)-darwin-arm64 $(CMD)

.PHONY: compose-prod-up compose-prod-up-service compose-prod-up-api compose-prod-down compose-prod-logs

compose-prod-up: ## Start all services with production Docker Compose
	$(DOCKER_COMPOSE) -f docker-compose.prod.yml up -d --build

compose-prod-up-service: ## Start a single service with production Docker Compose (SERVICE=api)
	@test -n "$(SERVICE)" || (echo "SERVICE is required" >&2; exit 1)
	@if [ "$(SERVICE)" = "api" ]; then \
		$(DOCKER_COMPOSE) -f docker-compose.prod.yml up -d --build "$(SERVICE)"; \
	else \
		echo "unsupported service: $(SERVICE)" >&2; exit 1; \
	fi

compose-prod-up-api: ## Start the api service with production Docker Compose
	$(MAKE) compose-prod-up-service SERVICE=api

compose-prod-down: ## Stop production Docker Compose services
	$(DOCKER_COMPOSE) -f docker-compose.prod.yml down

compose-prod-logs: ## Follow production Docker Compose logs
	$(DOCKER_COMPOSE) -f docker-compose.prod.yml logs -f

.PHONY: release
release: release-linux release-darwin ## Build release binaries
