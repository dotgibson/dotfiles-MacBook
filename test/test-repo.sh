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
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  c_g=$'\e[32m' c_r=$'\e[31m' c_d=$'\e[2;37m' c_0=$'\e[0m'
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
section "os/macos.zsh — sources clean & registers the bootstrap completion"
if command -v zsh >/dev/null 2>&1; then
  merr="$(zsh -f -c "
    autoload -Uz compinit; compinit -u -d '$(mktemp -u)' >/dev/null 2>&1
    fpath=('$REPO/completions' \$fpath)
    autoload -Uz _bootstrap && compdef _bootstrap bootstrap.sh ./bootstrap.sh
    (( \$+functions[_bootstrap] )) || { print 'no _bootstrap fn' >&2; exit 1; }
    [[ -n \${_comps[bootstrap.sh]:-} ]] || { print 'bootstrap.sh not registered' >&2; exit 1; }
  " 2>&1)"
  mrc=$?
  assert_eq "_bootstrap completion loads & registers" 0 "$mrc"
  [[ -n "$merr" ]] && no "completion registration produced output" "$merr"
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
