SHELL := /bin/bash
.DEFAULT_GOAL := help

# Command Line Tools ship Testing.framework but SwiftPM does not look there; a full Xcode needs no help.
CLT := /Library/Developer/CommandLineTools/Library/Developer
ifneq ($(findstring CommandLineTools,$(shell xcode-select -p 2>/dev/null)),)
TEST_FLAGS := -Xswiftc -F$(CLT)/Frameworks -Xlinker -F$(CLT)/Frameworks \
              -Xlinker -rpath -Xlinker $(CLT)/Frameworks -Xlinker -rpath -Xlinker $(CLT)/usr/lib
endif

.PHONY: help build bundle fixtures fixtures-real format format-check lint test coverage periphery secrets shellcheck check e2e e2e-full hooks signing clean

help: ## List targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

build: ## Build everything (warnings are errors in our own targets, see Package.swift)
	swift build

bundle: ## Build and sign build/Dictate.app and build/TestPad.app
	scripts/bundle.sh Dictate
	scripts/bundle.sh TestPad

fixtures: ## Generate speech fixtures with `say` (fixtures/generated)
	scripts/gen-fixtures.sh

fixtures-real: ## Download real human speech (FLEURS, CC-BY 4.0) into fixtures/private
	scripts/fetch-fleurs.sh

format: ## Auto-format Swift sources
	swiftformat Sources Tests Package.swift

format-check: ## Fail if formatting differs (no changes made)
	swiftformat Sources Tests Package.swift --lint

lint: ## SwiftLint in strict mode (warnings fail)
	scripts/swiftlint.sh

test: ## Unit tests with coverage data
	swift test --enable-code-coverage $(TEST_FLAGS)

coverage: ## Fail if DictateCore line coverage < 70%
	scripts/coverage.sh

periphery: ## Find unused code
	periphery scan --strict --quiet -- $(TEST_FLAGS)

secrets: ## Scan history and working tree for secrets
	gitleaks git --no-banner --redact
	gitleaks dir . --no-banner --redact

shellcheck: ## Lint shell scripts
	shellcheck scripts/*.sh

check: format-check lint build test coverage periphery secrets shellcheck ## Everything that must be green before a stage is done
	@echo "make check: OK"

e2e: bundle fixtures ## Smoke end-to-end suite, run once (needs macOS permissions; exit 2 = waiting for you)
	swift build --product E2ERunner
	@"$$(swift build --show-bin-path)/E2ERunner" --suite smoke; code=$$?; \
	 if [ $$code -eq 2 ]; then echo "make e2e: BLOCKED, needs your action (see BLOCKED lines above)"; fi; \
	 exit $$code

e2e-full: bundle fixtures ## Every end-to-end check, for a hand-off or on request (slow)
	swift build --product E2ERunner
	@"$$(swift build --show-bin-path)/E2ERunner" --suite full; code=$$?; \
	 if [ $$code -eq 2 ]; then echo "make e2e-full: BLOCKED, needs your action (see BLOCKED lines above)"; fi; \
	 exit $$code

hooks: ## Install git pre-commit hooks
	lefthook install

signing: ## One-time: create the stable code-signing identity
	scripts/setup-signing.sh

clean: ## Remove build output
	rm -rf .build build fixtures/generated
