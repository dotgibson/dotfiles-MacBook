# Makefile — single source of truth for lint/format. Humans and CI run the SAME
# commands, so "passes locally" means "passes in CI".
#
# Scope: only repo-owned files. `core/` is a vendored git-subtree from
# dotfiles-core and is linted in THAT repo's CI — reformatting it here would
# fight the subtree. A non-blocking `core-advisory` target surfaces core/ findings
# without gating. See README "Development".
#
# Quick start:  make lint   (run everything)   |   make fmt   (auto-format)

SHELL := bash
.DEFAULT_GOAL := help

# Repo-owned bash scripts: every *.sh outside the vendored core/ subtree.
SH_FILES := $(shell find . -name '*.sh' -not -path './core/*' -not -path './.git/*' | sort)
SHFMT_FLAGS := -i 2

.PHONY: help lint fmt fmt-check shellcheck syntax check core-advisory tools

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-13s\033[0m %s\n",$$1,$$2}'

lint: shellcheck fmt-check syntax ## Run all gating checks (shellcheck + format + syntax)

shellcheck: ## Static analysis of repo-owned bash
	@shellcheck $(SH_FILES)

fmt-check: ## Verify formatting without writing (CI uses this)
	@shfmt $(SHFMT_FLAGS) -d $(SH_FILES)

fmt: ## Auto-format repo-owned bash in place
	@shfmt $(SHFMT_FLAGS) -w $(SH_FILES)

syntax: ## `bash -n` syntax gate on every repo-owned script
	@for f in $(SH_FILES); do bash -n "$$f" || exit 1; done
	@echo "syntax ok:"; printf '  %s\n' $(SH_FILES)

core-advisory: ## Non-blocking shellcheck over vendored core/ (fixes land upstream)
	@shellcheck $$(find core -name '*.sh') || \
	  echo "(advisory) core/ findings above are fixed upstream in dotfiles-core"

check: lint ## Alias for `lint`

tools: ## Verify the lint toolchain is installed
	@for t in shellcheck shfmt; do \
	  command -v $$t >/dev/null && echo "  ok  $$t" \
	    || { echo "  MISSING $$t — run: brew bundle (or see Brewfile 'Dev: lint & format')"; exit 1; }; \
	done
