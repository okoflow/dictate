CONFIG        ?= debug
INDEX_STORE    = $(if $(wildcard .build/out/v5),.build/out,.build/debug/index/store)
TOOLCHAIN_DIR  = $(shell xcrun --find swift | sed 's|/usr/bin/swift$$||')

.PHONY: help build bundle run format check format-check lint periphery secrets shellcheck hooks signing clean

help: ## List targets
	@awk 'BEGIN { FS = ":.*## " } /^[a-z0-9-]+:.*## / { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build every target
	swift build --configuration $(CONFIG)

bundle: ## Build and sign build/Dictate.app
	scripts/bundle.sh $(CONFIG)

run: bundle ## Build, sign, and open Dictate
	open build/Dictate.app

format: ## Format Swift, shell, and the property list
	swiftformat .
	shfmt -w scripts
	plutil -convert xml1 Packaging/Dictate-Info.plist

check: format-check lint build periphery secrets shellcheck ## Run every check that CI runs
	@echo "make check: OK"

format-check: ## Fail on any formatting difference
	swiftformat . --lint
	shfmt -d scripts
	plutil -convert xml1 -o - Packaging/Dictate-Info.plist | diff -u Packaging/Dictate-Info.plist -

lint: ## Lint Swift sources in strict mode
	TOOLCHAIN_DIR=$(TOOLCHAIN_DIR) swiftlint lint --quiet

periphery: build ## Fail on unused code
	periphery scan --strict --quiet --retain-codable-properties --index-store-path $(INDEX_STORE)

secrets: ## Scan the git history for secrets
	gitleaks git --no-banner --redact

shellcheck: ## Lint shell scripts
	shellcheck scripts/*.sh

hooks: ## Install the git pre-commit hooks
	lefthook install

signing: ## Create the stable code-signing identity once
	scripts/setup-signing.sh

clean: ## Remove the build output
	rm -rf .build build
