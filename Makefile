SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help build bundle format format-check lint periphery secrets shellcheck check hooks signing clean

help: ## List targets
	@grep -E '^[a-z0-9-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

build: ## Build everything (warnings are errors in our own targets, see Package.swift)
	swift build

bundle: ## Build and sign build/Dictate.app
	scripts/bundle.sh Dictate

format: ## Auto-format Swift sources
	swiftformat Sources Package.swift

format-check: ## Fail if formatting differs (no changes made)
	swiftformat Sources Package.swift --lint

lint: ## SwiftLint in strict mode (warnings fail)
	scripts/swiftlint.sh

periphery: ## Find unused code
	periphery scan --strict --quiet

secrets: ## Scan history and working tree for secrets
	gitleaks git --no-banner --redact
	gitleaks dir . --no-banner --redact

shellcheck: ## Lint shell scripts
	shellcheck scripts/*.sh

check: format-check lint build periphery secrets shellcheck ## Everything that must be green before a change is done
	@echo "make check: OK"

hooks: ## Install git pre-commit hooks
	lefthook install

signing: ## One-time: create the stable code-signing identity
	scripts/setup-signing.sh

clean: ## Remove build output
	rm -rf .build build
