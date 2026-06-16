#!/usr/bin/env bash
# test/verify-core.sh — assert the vendored core/ subtree is BYTE-FOR-BYTE the upstream
# dotfiles-core commit it was vendored from.
# ──────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS: core/scripts/audit-core.sh proves the vendored tree is internally
# consistent, but it canNOT prove it equals upstream — its manifest lists some entries at
# DIRECTORY granularity (e.g. `tmux/scripts/`), so a file ADDED or a tracked file EDITED
# inside such a dir passes the audit while silently diverging from Core. Two real drifts of
# exactly that shape were found here: an orphaned tmux-sessionizer.sh (added, removed
# upstream) and an in-place edit of mise/config.toml. This is the backstop: diff the
# vendored core/ against upstream AT THE RECORDED SUBTREE-SPLIT COMMIT, so ANY difference is
# a genuine local modification — a `git subtree pull` conflict or a hand-edit — not just
# "we're behind upstream" (which comparing against HEAD would noisily flag).
#
# Best-effort + graceful, like the other gates: when upstream is unreachable (offline, a
# restricted runner) or no subtree marker exists, it SKIPS (exit 0) rather than failing —
# it can only verify what it can fetch. Override the upstream with CORE_UPSTREAM (a git URL
# or a local path); the default is the public dotfiles-core.
#
#   ./test/verify-core.sh                              # verify against the public upstream
#   CORE_UPSTREAM=/path/to/dotfiles-core ./test/verify-core.sh   # verify against a local clone
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  c_g=$'\e[32m' c_r=$'\e[31m' c_y=$'\e[33m' c_0=$'\e[0m'
else
  c_g='' c_r='' c_y='' c_0=''
fi
skip() {
  printf '%s–%s %s\n' "$c_y" "$c_0" "$*"
  exit 0
}
ok() { printf '%s✓%s %s\n' "$c_g" "$c_0" "$*"; }
fail() { printf '%s✗%s %s\n' "$c_r" "$c_0" "$*" >&2; }

command -v git >/dev/null 2>&1 || skip "verify-core: git not available"
[[ -d core ]] || skip "verify-core: no vendored core/ here"

# The upstream commit core/ was last vendored from — the subtree squash records it in the
# commit body as `git-subtree-split: <sha>` under `git-subtree-dir: core`.
SPLIT="$(git log --grep='git-subtree-dir: core' -n1 --format='%b' 2>/dev/null |
  sed -n 's/^[[:space:]]*git-subtree-split:[[:space:]]*//p' | head -n1)"
[[ -n "$SPLIT" ]] || skip "verify-core: no git-subtree-split marker (not a subtree checkout?)"

UPSTREAM="${CORE_UPSTREAM:-https://github.com/Gerrrt/dotfiles-core}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/verify-core.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# Fetch EXACTLY the recorded commit (shallow, like plugins.zsh does for pinned plugins) —
# GitHub serves arbitrary SHAs via fetch. A local-path CORE_UPSTREAM works the same way.
git -C "$TMP" init -q 2>/dev/null || skip "verify-core: cannot init a temp git workspace"
git -C "$TMP" remote add origin "$UPSTREAM" 2>/dev/null
if ! git -C "$TMP" fetch -q --depth 1 origin "$SPLIT" 2>/dev/null; then
  skip "verify-core: upstream commit ${SPLIT:0:12} not fetchable from $UPSTREAM (offline/restricted) — cannot verify"
fi
git -C "$TMP" checkout -q FETCH_HEAD 2>/dev/null || skip "verify-core: could not check out ${SPLIT:0:12}"
rm -rf "$TMP/.git" # compare working trees only

# Byte-for-byte diff: upstream tree (files at its root) vs the vendored core/. `diff -rq`
# reports both content differences AND files present on only one side (orphans / omissions).
echo ":: vendored core/ vs upstream dotfiles-core @ ${SPLIT:0:12}"
if diff -rq "$TMP" core >"$TMP.diff" 2>&1; then
  ok "vendored core/ is byte-for-byte upstream @ ${SPLIT:0:12}"
  exit 0
fi
fail "vendored core/ DIFFERS from upstream @ ${SPLIT:0:12} — a subtree conflict or a hand-edit:"
# Re-point diff's temp-dir paths at the friendlier 'upstream'/'core' labels for the report.
sed -e "s#${TMP}#upstream#g" "$TMP.diff" | sed 's/^/    /' >&2
fail "fix: revert the local change (edit upstream + re-sync), or re-run the subtree pull cleanly"
exit 1
