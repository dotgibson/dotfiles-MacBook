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

# Repo-owned zsh modules. These are the real behavioral surface of this repo, yet
# the .sh-only globs above never reach them (the entry files have NO extension).
# `zsh -n` parses each so a broken edit can't ship green. core/ zsh is gated in
# dotfiles-core's own CI.
ZSH_FILES := zsh/zshenv zsh/zprofile zsh/zshrc os/macos.zsh

.PHONY: help lint fmt fmt-check shellcheck syntax zsh-syntax check core-advisory \
        tools test bench bootstrap bootstrap-dry doctor sync-core

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-15s\033[0m %s\n",$$1,$$2}'

lint: shellcheck fmt-check syntax zsh-syntax ## Run all gating checks (shellcheck + format + bash/zsh syntax)

shellcheck: ## Static analysis of repo-owned bash
	@shellcheck $(SH_FILES)

fmt-check: ## Verify formatting without writing (CI uses this)
	@shfmt $(SHFMT_FLAGS) -d $(SH_FILES)

fmt: ## Auto-format repo-owned bash in place
	@shfmt $(SHFMT_FLAGS) -w $(SH_FILES)

syntax: ## `bash -n` syntax gate on every repo-owned script
	@for f in $(SH_FILES); do bash -n "$$f" || exit 1; done
	@echo "syntax ok:"; printf '  %s\n' $(SH_FILES)

zsh-syntax: ## `zsh -n` syntax gate on repo-owned zsh modules (skips if zsh absent)
	@command -v zsh >/dev/null 2>&1 || { echo "  skip zsh-syntax (zsh not installed)"; exit 0; }
	@for f in $(ZSH_FILES); do zsh -n "$$f" || exit 1; done
	@echo "zsh syntax ok:"; printf '  %s\n' $(ZSH_FILES)

core-advisory: ## Non-blocking shellcheck over vendored core/ (fixes land upstream)
	@shellcheck $$(find core -name '*.sh') || \
	  echo "(advisory) core/ findings above are fixed upstream in dotfiles-core"

test: ## Run the vendored Core regression harness (self-skips without zsh)
	@cd core && ./scripts/test-core.sh

bench: ## Measure Core shell-startup cost (set CORE_BENCH_BUDGET_MS to gate)
	@cd core && ./scripts/bench-core.sh

bootstrap: ## Install: symlinks + Homebrew + brew bundle (macOS)
	@./bootstrap.sh

bootstrap-dry: ## Preview the installer plan (symlinks); change nothing
	@./bootstrap.sh --links-only --dry-run

doctor: ## Show what bootstrap would change + verify the lint toolchain
	@./bootstrap.sh --links-only --dry-run || true
	@$(MAKE) -s tools || true

sync-core: ## Reminder: pull the latest vendored Core subtree, then relink
	@echo "  git subtree pull --prefix=core <remote>/dotfiles-core main --squash"
	@echo "  ./bootstrap.sh --links-only   # re-wire any new/changed Core files"
	@echo "  make test                     # prove the new Core still loads"

check: lint ## Alias for `lint`

tools: ## Verify the lint toolchain is installed
	@for t in shellcheck shfmt; do \
	  command -v $$t >/dev/null && echo "  ok  $$t" \
	    || { echo "  MISSING $$t — run: brew bundle (or see Brewfile 'Dev: lint & format')"; exit 1; }; \
	done
