#!/usr/bin/env bash
# test/check-core-freshness.sh — is the vendored core/ subtree BEHIND upstream?
# ──────────────────────────────────────────────────────────────────────────────
# B7 (verify-core.sh) proves core/ MATCHES the commit it was vendored from. This is the
# complementary freshness watcher: it asks whether that vendored commit is now BEHIND
# upstream's tip — i.e. there are Core updates this repo hasn't pulled. dotfiles-core has
# its own freshness.yml for its plugin pins; this is the consumer-side equivalent for the
# subtree itself, which nothing otherwise tracks. A behind result is the NUDGE to run a
# `git subtree pull` (see `make sync-core`), not a hard error in normal development — so it
# lives in a SCHEDULED workflow, exiting non-zero only there to surface the drift.
#
# Best-effort + graceful (offline/restricted → skip, exit 0). Override the upstream and the
# branch with CORE_UPSTREAM / CORE_BRANCH.
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  c_g=$'\e[32m' c_y=$'\e[33m' c_0=$'\e[0m'
else c_g='' c_y='' c_0=''; fi
skip() {
  printf '%s–%s %s\n' "$c_y" "$c_0" "$*"
  exit 0
}

command -v git >/dev/null 2>&1 || skip "check-core-freshness: git unavailable"
SPLIT="$(git log --grep='git-subtree-dir: core' -n1 --format='%b' 2>/dev/null |
  sed -n 's/^[[:space:]]*git-subtree-split:[[:space:]]*//p' | head -n1)"
[[ -n "$SPLIT" ]] || skip "check-core-freshness: no git-subtree-split marker (not a subtree checkout?)"

UPSTREAM="${CORE_UPSTREAM:-https://github.com/Gerrrt/dotfiles-core}"
BRANCH="${CORE_BRANCH:-main}"

# The upstream tip we'd be pulling. ls-remote needs no clone and is the source of truth.
TIP="$(git ls-remote "$UPSTREAM" "$BRANCH" 2>/dev/null | awk 'NR==1{print $1}')"
[[ -n "$TIP" ]] || skip "check-core-freshness: cannot reach $UPSTREAM ($BRANCH) — offline/restricted?"

if [[ "$TIP" == "$SPLIT" ]]; then
  printf '%s✓%s vendored core/ is current with %s@%s (%s)\n' "$c_g" "$c_0" "$UPSTREAM" "$BRANCH" "${SPLIT:0:12}"
  exit 0
fi

# Behind (or diverged). Report the SHAs and how to update. Exit non-zero so a scheduled
# run surfaces it (the workflow turns this into a step-summary nudge).
printf '%s⚠%s vendored core/ is behind upstream %s@%s\n' "$c_y" "$c_0" "$UPSTREAM" "$BRANCH" >&2
printf '    vendored: %s\n    upstream: %s\n' "${SPLIT:0:12}" "${TIP:0:12}" >&2
printf '    update:   make sync-core   (git subtree pull --prefix=core <remote> %s --squash)\n' "$BRANCH" >&2
exit 1
