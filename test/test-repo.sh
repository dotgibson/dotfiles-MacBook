#!/usr/bin/env bash
# test/test-repo.sh — behavioral regression harness for THIS repo's own code.
# ──────────────────────────────────────────────────────────────────────────────
# `make test` runs the VENDORED Core harness (core/scripts/test-core.sh). That never
# touches the repo-owned surface: bootstrap.sh (symlink/backup/seed/dry-run/arg-parse),
# the zsh loader in zsh/zshrc, the macOS interactive layer, or macos/defaults.sh. Those
# are the highest-risk, hardest-to-reverse scripts here and were previously gated only
# by `bash -n`/`zsh -n` (syntax, not behaviour). This harness closes that gap.
#
# It is HERMETIC and runs anywhere (Linux CI included): bootstrap.sh is macOS-only, so
# we set BOOTSTRAP_ALLOW_NON_DARWIN=1 and only ever exercise its --dry-run / arg-parse /
# output paths — never a real provision. Every mutation is sandboxed under a temp HOME.
# zsh-dependent checks self-skip when zsh is absent (matching test-core.sh's contract).
#
#   ./test/test-repo.sh            # run everything
#   ./test/test-repo.sh --quiet    # only print failures + the summary
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

# ── tiny assert framework ─────────────────────────────────────────────────────
# Palette from the VENDORED shared bash UX lib (core/lib/ux.sh) — ONE colour rule across
# the repo's bash instead of a hand-rolled TTY/NO_COLOR block that drifts (B4). Maps UX_*
# onto the c_* names this harness already uses. Guarded so the harness still runs if core/
# is somehow absent (degrades to no colour, never an unbound-var error under set -u).
if [[ -r "$REPO/core/lib/ux.sh" ]]; then
  # shellcheck source=/dev/null
  source "$REPO/core/lib/ux.sh"
  c_g=$UX_GRN c_r=$UX_RED c_d=$UX_DIM c_0=$UX_RST
else
  c_g='' c_r='' c_d='' c_0=''
fi
pass=0 fail=0 skip=0
ok() {
  pass=$((pass + 1))
  ((QUIET)) || printf '  %s✓%s %s\n' "$c_g" "$c_0" "$1"
}
no() {
  fail=$((fail + 1))
  printf '  %s✗%s %s\n' "$c_r" "$c_0" "$1" >&2
  [[ -n "${2:-}" ]] && printf '      %s%s%s\n' "$c_d" "$2" "$c_0" >&2
}
skipt() {
  skip=$((skip + 1))
  ((QUIET)) || printf '  %s· skip%s %s\n' "$c_d" "$c_0" "$1"
}
section() { ((QUIET)) || printf '\n%s== %s ==%s\n' "$c_d" "$1" "$c_0"; }

# assert_eq <desc> <expected> <actual>
assert_eq() { if [[ "$2" == "$3" ]]; then ok "$1"; else no "$1" "expected '$2', got '$3'"; fi; }
# assert_contains <desc> <haystack> <needle>
assert_contains() { if [[ "$2" == *"$3"* ]]; then ok "$1"; else no "$1" "missing '$3' in: $2"; fi; }
# assert_not_contains <desc> <haystack> <needle>
assert_not_contains() { if [[ "$2" != *"$3"* ]]; then ok "$1"; else no "$1" "unexpected '$3' present"; fi; }

# Run bootstrap.sh in a throwaway HOME, capturing stdout+stderr and the exit code.
# Sets globals OUT (combined output) and RC (exit status). Never provisions.
SANDBOX=""
run_bootstrap() { # run_bootstrap <piped|tty-irrelevant> <args...>
  shift
  local home
  home="$(mktemp -d)"
  SANDBOX="$home"
  OUT="$(HOME="$home" BOOTSTRAP_ALLOW_NON_DARWIN=1 NO_COLOR='' bash "$REPO/bootstrap.sh" "$@" 2>&1)"
  RC=$?
}

# ── A. bootstrap.sh: help + arg parsing ───────────────────────────────────────
section "bootstrap.sh — help & argument parsing"

OUT="$(bash "$REPO/bootstrap.sh" --help 2>&1)"
RC=$?
assert_eq "--help exits 0" 0 "$RC"
assert_contains "--help prints the banner" "$OUT" "bootstrap.sh — idempotent"

OUT="$(bash "$REPO/bootstrap.sh" --bogus 2>&1)"
RC=$?
assert_eq "unknown flag exits 2 (usage-error convention)" 2 "$RC"
assert_contains "unknown flag names the offender" "$OUT" "unknown flag: --bogus"

# did-you-mean (U4): hyphen-slip typos should suggest the real flag.
for pair in "--dryrun:--dry-run" "--link-only:--links-only" "--nobrew:--no-brew" "--setshell:--set-shell"; do
  typo="${pair%%:*}" want="${pair##*:}"
  OUT="$(bash "$REPO/bootstrap.sh" "$typo" 2>&1)"
  assert_contains "typo '$typo' suggests '$want'" "$OUT" "did you mean $want?"
done
# An unrelated token must NOT produce a bogus suggestion.
OUT="$(bash "$REPO/bootstrap.sh" --zzzzzz 2>&1)"
assert_not_contains "unrelated typo gives no false suggestion" "$OUT" "did you mean"

# ── B. bootstrap.sh: dry-run is a true no-op + scannable output ────────────────
section "bootstrap.sh — dry-run plan (hermetic, no mutations)"

run_bootstrap piped --links-only --dry-run
assert_eq "dry-run exits 0" 0 "$RC"
assert_contains "dry-run announces itself" "$OUT" "DRY RUN"
assert_contains "dry-run prints a run summary" "$OUT" "linked ·"
assert_contains "dry-run closes with the safe-to-rerun note" "$OUT" "re-run without --dry-run"

# Output piped (not a TTY) must be free of raw ANSI escapes (U1).
esc=$(printf '%s' "$OUT" | grep -c $'\e' || true)
assert_eq "piped output carries no ANSI escape bytes" 0 "$esc"

# A dry run must not create ANYTHING in the sandbox HOME (no symlinks, no backups).
created=$(find "$SANDBOX" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
assert_eq "dry-run creates zero files in HOME" 0 "$created"
[[ -n "$SANDBOX" ]] && rm -rf "$SANDBOX"

# ── B1b. bootstrap.sh: a REAL apply creates the links + is idempotent (B8) ─────
# The CI macOS job only ever ran `--links-only --dry-run` (the PLAN), so a regression in
# the actual link/seed step — a renamed source, a broken wire_links edit — could ship
# green. This exercises a real apply against a sandboxed HOME and asserts the links land
# (pointing INTO the repo), seeds are real files, a re-apply is idempotent, and the
# apply→uninstall round-trip is clean. Hermetic: pre-seed tpm so wire_links skips the
# network clone, and stub `mise` so the post-link `mise install` is an instant no-op
# whether or not real mise is on PATH. Runs on Linux CI too (BOOTSTRAP_ALLOW_NON_DARWIN).
section "bootstrap.sh — real apply creates links, idempotent, round-trips (B8)"

ahome="$(mktemp -d)"
abin="$(mktemp -d)"
mkdir -p "$ahome/.config/tmux/plugins/tpm"
printf '#!/bin/sh\nexit 0\n' >"$abin/mise"
chmod +x "$abin/mise"
OUT="$(HOME="$ahome" PATH="$abin:$PATH" BOOTSTRAP_ALLOW_NON_DARWIN=1 NO_COLOR=1 bash "$REPO/bootstrap.sh" --no-brew --links-only 2>&1)"
arc=$?
((arc == 0)) || printf '%s\n' "$OUT" | sed 's/^/    [apply diag] /' >&2 # surface where it stopped
assert_eq "apply (--no-brew --links-only) exits 0" 0 "$arc"
for l in .zshenv .config/zsh/.zshrc .config/starship.toml .config/nvim .local/bin/clip; do
  tgt="$(readlink "$ahome/$l" 2>/dev/null || true)"
  case "$tgt" in
  "$REPO"/*) ok "apply linked $l → repo" ;;
  *) no "apply linked $l → repo" "got: ${tgt:-<missing>}" ;;
  esac
done
if [[ -f "$ahome/.config/git/local.gitconfig" && ! -L "$ahome/.config/git/local.gitconfig" ]]; then
  ok "apply seeded local.gitconfig as a real file (editable, not a symlink)"
else
  no "apply seeded local.gitconfig as a real file" "missing or a symlink"
fi
OUT="$(HOME="$ahome" PATH="$abin:$PATH" BOOTSTRAP_ALLOW_NON_DARWIN=1 NO_COLOR=1 bash "$REPO/bootstrap.sh" --no-brew --links-only 2>&1)"
arc=$?
((arc == 0)) || printf '%s\n' "$OUT" | sed 's/^/    [re-apply diag] /' >&2
assert_eq "re-apply exits 0 (idempotent)" 0 "$arc"
assert_contains "re-apply reports an already-linked file" "$OUT" "already linked"
HOME="$ahome" BOOTSTRAP_ALLOW_NON_DARWIN=1 NO_COLOR=1 bash "$REPO/bootstrap.sh" --uninstall >/dev/null 2>&1
if [[ -L "$ahome/.zshenv" ]]; then no "apply→uninstall round-trip removes the links" "still a link"; else ok "apply→uninstall round-trip removes the links"; fi
rm -rf "$ahome" "$abin"

# ── B2. bootstrap.sh --uninstall: reverse links + restore backups (B4) ─────────
section "bootstrap.sh — uninstall (reverse symlinks, restore backups, skip foreign)"

# dry-run uninstall is a true no-op + scannable.
run_bootstrap piped --uninstall --dry-run
assert_eq "uninstall --dry-run exits 0" 0 "$RC"
assert_contains "uninstall --dry-run announces itself" "$OUT" "DRY RUN"
assert_contains "uninstall prints its summary" "$OUT" "uninstall summary"
created=$(find "$SANDBOX" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
assert_eq "uninstall --dry-run creates nothing" 0 "$created"
[[ -n "$SANDBOX" ]] && rm -rf "$SANDBOX"

# functional: a Core symlink + its backup is reversed; a FOREIGN symlink is left alone.
uhome="$(mktemp -d)"
ucfg="$uhome/.config/zsh"
mkdir -p "$ucfg"
ln -s "$REPO/zsh/zshrc" "$ucfg/.zshrc"                           # ours (points into the repo)
printf 'ORIGINAL\n' >"$ucfg/.zshrc.pre-dotfiles.20250101-120000" # a prior backup
ln -s /etc/hostname "$ucfg/aliases.zsh"                          # foreign (not into the repo)
OUT="$(HOME="$uhome" BOOTSTRAP_ALLOW_NON_DARWIN=1 NO_COLOR=1 bash "$REPO/bootstrap.sh" --uninstall 2>&1)"
assert_eq "uninstall exits 0" 0 "$?"
if [[ -L "$ucfg/.zshrc" ]]; then no "uninstall removed our symlink" "still a link"; else ok "uninstall removed our symlink"; fi
assert_eq "uninstall restored the backup over it" "ORIGINAL" "$(cat "$ucfg/.zshrc" 2>/dev/null)"
if [[ -L "$ucfg/aliases.zsh" ]]; then ok "uninstall left a FOREIGN symlink untouched"; else no "uninstall left a foreign symlink untouched" "it was removed"; fi
assert_contains "uninstall flags the foreign link as not-ours" "$OUT" "not ours"
rm -rf "$uhome"

# safety: if the user replaced our symlink with a REAL file, uninstall must NOT clobber it
# with a stale backup (it must leave real files untouched). Regression for the data-loss
# path Copilot flagged: a real file at $dest + a .pre-dotfiles.* backup present.
shome="$(mktemp -d)"
scfg="$shome/.config/zsh"
mkdir -p "$scfg"
printf 'USER REAL FILE\n' >"$scfg/.zshrc"                            # a real file the user put there
printf 'STALE BACKUP\n' >"$scfg/.zshrc.pre-dotfiles.20240101-000000" # an old backup also present
OUT="$(HOME="$shome" BOOTSTRAP_ALLOW_NON_DARWIN=1 NO_COLOR=1 bash "$REPO/bootstrap.sh" --uninstall 2>&1)"
assert_eq "uninstall does NOT overwrite a real file with a stale backup" "USER REAL FILE" "$(cat "$scfg/.zshrc" 2>/dev/null)"
assert_contains "uninstall reports it skipped the real file" "$OUT" "real file present"
rm -rf "$shome"

# ── C. zsh loader (zsh/zshrc) actually executes ───────────────────────────────
# `make zsh-syntax` only parses (zsh -n). This sources the real loop against a
# hermetic ZDOTDIR of stub modules and asserts it runs clean AND sources in order.
section "zsh/zshrc — loader executes (not just parses)"
if command -v zsh >/dev/null 2>&1; then
  zhome="$(mktemp -d)"
  zcfg="$zhome/zsh"
  mkdir -p "$zcfg"
  # One stub per module the loop sources; each appends its name to an order log so we
  # can prove the canonical order. (zshrc skips any module that's absent.)
  modules=(tools options history aliases git functions fzf bindings plugins op maint update os local)
  for m in "${modules[@]}"; do
    # The $ZSH_ORDER_LOG ref is meant to expand inside the stub at zsh runtime, not here.
    # shellcheck disable=SC2016
    printf 'print -r -- %s >> "$ZSH_ORDER_LOG"\n' "$m" >"$zcfg/$m.zsh"
  done
  # zshrc now sources the VENDORED loader (B12) rather than an inline loop, so the sandbox
  # needs loader.zsh present (bootstrap symlinks it from core/zsh/ in a real install). 'ui'
  # has no stub above, so the loader skips it (its `[[ -r ]] || continue`) and the order log
  # matches $modules — exercising the real skip path too.
  ln -s "$REPO/core/zsh/loader.zsh" "$zcfg/loader.zsh"
  order_log="$zhome/order.log"
  zerr="$(ZDOTDIR="$zcfg" ZSH_ORDER_LOG="$order_log" zsh -f -c "source '$REPO/zsh/zshrc'" 2>&1)"
  zrc=$?
  assert_eq "loader sources cleanly (exit 0)" 0 "$zrc"
  assert_eq "loader produced no errors" "" "$zerr"
  got_order="$(tr '\n' ' ' <"$order_log" 2>/dev/null | sed 's/ $//')"
  assert_eq "modules sourced in canonical order" "${modules[*]}" "$got_order"
  # zcompile self-heal: a .zwc should appear next to a sourced stub.
  if compgen -G "$zcfg"/*.zwc >/dev/null; then
    ok "loader byte-compiles modules (.zwc written beside the symlink)"
  else
    skipt "zcompile produced no .zwc (acceptable on this zsh build)"
  fi
  rm -rf "$zhome"
else
  skipt "zsh absent — skipping loader execution checks"
  skipt "zsh absent — skipping loader order check"
fi

# ── D. macOS interactive layer + repo-owned completion ────────────────────────
# Source the REAL os/macos.zsh (not a re-implementation) so its actual fpath/compdef
# wiring — including the ${…:A:h:h}/completions path resolution — is what's under test.
# The script is single-quoted and the temp dump path + repo root are passed as
# positional args ($1/$2), so there is no nested bash/zsh substitution to get wrong.
# compinit must run first (os.zsh guards on compdef); the auto-tmux exec at os.zsh's
# tail self-skips here because stdout isn't a TTY (its `-t 1` guard is false).
section "os/macos.zsh — sources clean & registers the bootstrap completion"
if command -v zsh >/dev/null 2>&1; then
  oshome="$(mktemp -d)"
  merr="$(ZDOTDIR="$oshome" zsh -f -c '
    autoload -Uz compinit && compinit -u -d "$1" >/dev/null 2>&1
    source "$2/os/macos.zsh"
    (( $+functions[_bootstrap] )) || { print "_bootstrap not autoloaded by os/macos.zsh" >&2; exit 1; }
    [[ -n ${_comps[bootstrap.sh]:-} ]] || { print "bootstrap.sh completion not registered" >&2; exit 1; }
  ' zsh-test "$oshome/.zcompdump" "$REPO" 2>&1)"
  mrc=$?
  assert_eq "os/macos.zsh sources clean & registers _bootstrap completion" 0 "$mrc"
  [[ -n "$merr" ]] && no "sourcing os/macos.zsh produced unexpected output" "$merr"
  rm -rf "$oshome"
else
  skipt "zsh absent — skipping completion registration check"
fi

# ── E. macos/defaults.sh: arg parsing + dry-run summary ───────────────────────
section "macos/defaults.sh — arg parsing & dry-run"
OUT="$(bash "$REPO/macos/defaults.sh" -h 2>&1)"
RC=$?
assert_eq "defaults.sh -h exits 0" 0 "$RC"
OUT="$(bash "$REPO/macos/defaults.sh" --bogus 2>&1)"
RC=$?
assert_eq "defaults.sh rejects unknown arg (exit 2)" 2 "$RC"
assert_contains "defaults.sh names the bad arg" "$OUT" "unknown argument: --bogus"
# Dry-run shadows every mutator, so it is safe to execute even off-macOS.
OUT="$(bash "$REPO/macos/defaults.sh" --dry-run 2>&1)"
RC=$?
assert_eq "defaults.sh --dry-run exits 0" 0 "$RC"
assert_contains "defaults.sh --dry-run prints a summary" "$OUT" "nothing changed"
esc=$(printf '%s' "$OUT" | grep -c $'\e' || true)
assert_eq "defaults.sh piped output carries no ANSI escapes" 0 "$esc"

# ── F. ghostty/config — seeded but otherwise un-validated ─────────────────────
# ghostty has no headless config-lint, so we can't truly parse it; but a smoke check
# catches gross corruption a symlink would happily wire up — a merge-conflict marker,
# a stray paste, a truncated file. ghostty's format is `key = value` (or `#` comments),
# so every non-blank, non-comment line must contain '='. Cheap; catches the real breakage.
section "ghostty/config — no obvious corruption (key = value lines)"
if [[ -s "$REPO/ghostty/config" ]]; then
  bad="$(grep -vE '^\s*(#|$)' "$REPO/ghostty/config" | grep -vE '=' || true)"
  if [[ -z "$bad" ]]; then
    ok "ghostty/config: every directive is a key = value line"
  else
    no "ghostty/config has non-comment line(s) without '='" "$(printf '%s' "$bad" | head -3)"
  fi
else
  no "ghostty/config is missing or empty" "expected a seeded config at ghostty/config"
fi

# ── summary ───────────────────────────────────────────────────────────────────
printf '\n%s──────── repo test summary ────────%s\n' "$c_d" "$c_0"
printf '  %spass %d%s   %sskip %d%s   ' "$c_g" "$pass" "$c_0" "$c_d" "$skip" "$c_0"
if ((fail)); then
  printf '%sfail %d%s\n' "$c_r" "$fail" "$c_0"
  printf '%srepo tests FAILED%s\n' "$c_r" "$c_0" >&2
  exit 1
fi
printf 'fail 0\n'
printf '%srepo tests OK%s\n' "$c_g" "$c_0"
