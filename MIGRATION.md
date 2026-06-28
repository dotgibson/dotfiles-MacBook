# Migrating the Mac from `~/.config`-as-repo → `~/dotfiles-MacBook`

Right now your Mac is the odd one out: the repo **is** `~/.config` (you cloned it
straight there, and `$ZDOTDIR` + `dotsync` point inside it). The other nine repos
live at `~/dotfiles-*` and _symlink_ into `~/.config`. This runbook moves the
Mac onto that same model so `sync-core.sh` and every assumption works uniformly.

It is written to be **safe on your daily driver**: you take a full backup first,
nothing is deleted until the new setup is verified, and there's a rollback at the
bottom. Do this when you have 20 quiet minutes — not five minutes before a meeting.

> Throughout, `<REMOTE>` = your GitHub base, e.g. `git@github.com:Gerrrt`.

---

## 0. Pre-flight (in the current `~/.config`)

```bash
cd ~/.config
git status                      # commit/stash anything outstanding
git add -A && git commit -m "pre-migration snapshot" || true
git push
```

Confirm clean + pushed before continuing. GitHub is your off-machine backup.

---

## 1. Full local backup (the safety net)

```bash
tar -czf "$HOME/config-backup-$(date +%Y%m%d-%H%M%S).tar.gz" -C "$HOME" .config
ls -lh "$HOME"/config-backup-*.tar.gz      # confirm it exists and is non-trivial
```

If anything goes sideways, §Rollback restores from this.

---

## 2. Build the new repo at `~/dotfiles-MacBook`

Push the **new** structure (the files from this session: `bootstrap.sh`, `os/`,
`zsh/`, `Brewfile`, `macos/`, `ssh/`, README, `.gitignore`) to your
`dotfiles-MacBook` remote, then:

```bash
git clone <REMOTE>/dotfiles-MacBook ~/dotfiles-MacBook
cd ~/dotfiles-MacBook

# one-time: vendor Core as a subtree (same as the other repos)
git subtree add --prefix=core <REMOTE>/dotfiles-core main --squash

# make the popup scripts executable (the outputs filesystem can't carry +x)
chmod +x core/tmux/scripts/*.sh core/bin/clip core/bin/clip-paste
git add -A && git commit -m "mark scripts executable" || true
git push
```

> Don't run `bootstrap.sh` yet — first clear the old repo-ness from `~/.config`
> in the next step, or the two will fight over the same files.

---

## 3. Turn `~/.config` back into a plain directory

`~/.config` holds two kinds of things: files your **old repo tracked** (these get
recreated as symlinks) and configs **other apps** dropped there (these stay
untouched). We use git itself to tell them apart, so only the right files move.

```bash
cd ~/.config

# record exactly what the old repo tracked (for reference / cleanup)
git ls-files > ~/.config-old-tracked.txt
wc -l ~/.config-old-tracked.txt

# remove ONLY the old tracked files (everything is backed up + on GitHub)
git ls-files -z | xargs -0 rm -f

# prune now-empty dirs left behind (won't touch dirs other apps still use)
find ~/.config -type d -empty -delete 2>/dev/null || true

# stop ~/.config from being a git repo (keep the old .git aside, just in case)
mv ~/.config/.git ~/.config-old.git
```

Your running shell keeps working — it already loaded its config into memory.

---

## 4. Wire the new symlinks

```bash
cd ~/dotfiles-MacBook
./bootstrap.sh --links-only        # symlinks Core + os/ into ~/.config and ~
```

`bootstrap` backs up any stray real file it finds at a target (as
`*.pre-dotfiles.<timestamp>`) before linking, so this is non-destructive even if
step 3 missed something. It also seeds `~/.config/git/local.gitconfig` — open it
and put your real name/email there (it's never tracked):

```bash
$EDITOR ~/.config/git/local.gitconfig     # [user] name + email (+ signingkey if you sign)
```

Then provision packages and apply system prefs when ready:

```bash
./bootstrap.sh                     # Homebrew + brew bundle (full run)
./bootstrap.sh --macos-defaults    # optional: apply macos/defaults.sh
```

---

## 5. Verify

```bash
exec zsh                           # fresh shell off the new symlinks
echo "$ZDOTDIR"                    # → ~/.config/zsh
ls -la ~/.zshenv ~/.config/zsh/.zshrc ~/.gitconfig ~/.config/nvim   # all symlinks → ~/dotfiles-MacBook/...
```

Smoke test the things most likely to reveal a bad link:

- prompt loads (starship), `z`/`Ctrl+R` (atuin)/`Ctrl+G` (sessionizer) work
- `nvim` opens clean (`:checkhealth` if paranoid); `"+yy` then paste elsewhere (clipboard)
- `tmux` → `prefix+w` / `prefix+T` / `prefix+f` popups open (the promoted scripts)
- `git config --get user.email` returns your local identity; `git diff` shows delta
- `dotsync` lands you in `~/dotfiles-MacBook`

---

## 6. Clean up (only once everything above is green)

```bash
# orphaned per-target backups bootstrap may have made
find ~ ~/.config -maxdepth 2 -name '*.pre-dotfiles.*' -print   # review, then delete
rm -rf ~/.config-old.git ~/.config-old-tracked.txt
# keep the tarball a few days, then:
# rm ~/config-backup-*.tar.gz
```

---

## Rollback (if anything is wrong before cleanup)

```bash
# remove the half-migrated config and restore the snapshot
rm -rf ~/.config
tar -xzf ~/config-backup-<stamp>.tar.gz -C "$HOME"
mv ~/.config-old.git ~/.config/.git 2>/dev/null || true
exec zsh
```

You're back to the pre-migration state. Nothing about `~/dotfiles-MacBook` or the
GitHub repos is affected, so you can retry whenever.
