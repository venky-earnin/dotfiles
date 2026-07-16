# Dotfiles

Curated macOS developer setup for shell, Git, tmux, WezTerm, Neovim, and
coding-agent workflows.

This repo is allowlist-based. It intentionally excludes auth material, histories, runtime state, caches, project memories, package-index credentials, and per-machine config.

## Layout

- `home/` mirrors files that can be linked into `$HOME`.
- `home/bin/` contains reusable helper scripts such as `agent-worktree`, `agent-inbox`, and `agent-recall`.
- `home/.config/agents/` contains the shared agent behavior file, collaboration
  workflow docs, `agent-review` ledger tool, shared hooks, and lightweight tests.
- `home/.claude/` contains Claude-specific commands, hooks, and settings.
- `home/.codex/` contains public-safe Codex hook and command-rule defaults.
- `scripts/bootstrap.sh` links the curated files into a machine.
- `scripts/check.sh` runs syntax, whitespace, sensitive-content, and dry-run checks.
- `scripts/smoke-clean-home.sh` bootstraps into a temporary `$HOME` to verify
  the link layout without changing the real machine.
- `scripts/check-sensitive.sh` blocks obvious secrets and noisy state before commit/push.

## Install

Prerequisites:

- macOS
- Git
- Homebrew, if installing packages from `Brewfile`

This setup has two parts:

- Dotfiles are linked into `$HOME` by `scripts/bootstrap.sh`.
- Developer tools are installed from `Brewfile` with Homebrew.

Review first:

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./scripts/check-sensitive.sh
./scripts/bootstrap.sh --dry-run
```

Apply:

```bash
./scripts/bootstrap.sh
```

The bootstrap script asks whether to install the command-line tools from
`Brewfile`. For an explicit full setup, run:

```bash
./scripts/bootstrap.sh --install-tools
```

For a dotfiles-only setup, run:

```bash
./scripts/bootstrap.sh --skip-tools
```

Equivalent manual tool install:

```bash
brew bundle --file Brewfile
```

Optional GitHub CLI extension:

```bash
gh extension install dlvhdr/gh-dash
```

If Homebrew is not installed yet, install it from `https://brew.sh`, then rerun
`./scripts/bootstrap.sh --install-tools`.

## Validate

Run the local checks before pushing changes:

```bash
./scripts/check.sh
```

Run a clean-home smoke test to verify the bootstrap script can link the setup
into an empty temporary `$HOME`:

```bash
./scripts/smoke-clean-home.sh
```

The repository also includes a macOS GitHub Actions workflow that runs both
checks on push and pull request.

## Tooling Overview

- Shell navigation and history: `zoxide`, `atuin` reverse search, `fzf`,
  `fzf-tab`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `starship`,
  and `direnv`.
- Search, file, and data utilities: `rg`, `fd`, `eza`, `bat`, `jq`, `yq`,
  `sd`, `ast-grep`, `tree`, `tokei`, `duf`, `dust`, `btop`, and `procs`.
- Git and review tools: `gh`, `git-delta`, `git-absorb`, `difftastic`,
  `lazygit`, `jj`, `git-spice`, `git-lfs`, and `gitleaks`.
- Language/runtime helpers: `mise`, `uv`, `pipx`, `go`, `node`,
  `python@3.12`, `openjdk@11`, `tree-sitter-cli`, `shellcheck`, `shfmt`, and
  `stylua`.
- Terminal and editor: `tmux`, `WezTerm`, `Neovim`, and Nerd Fonts.
- Workflow extras: `hyperfine`, `glow`, `gum`, `just`, `sesh`, `tldr`, `rtk`,
  `terminal-notifier`, and `watch`.
- Agent workflow helpers: shared `AGENTS.md`, Codex/Claude compatibility
  symlinks, `agent-worktree`, `agent-inbox`, `agent-recall`, `agent-tmp`, and
  the `agent-review` local review ledger.
- Agent hardening defaults: Claude and Codex hook wiring, a publish guard for
  push/PR/merge operations, shared review-state reminders, recall-on-error, and
  public-safe Codex rules that prompt before publishing while leaving
  machine-specific allow rules out of the repo.

### Agent plugin compatibility

Keep `warp@claude-code-warp` disabled in Codex. Its hook manifest launches
`Stop`, `UserPromptSubmit`, and related scripts through
`${CLAUDE_PLUGIN_ROOT}`, which is a Claude Code plugin variable and does not
resolve in Codex's hook runner. Enabling it in Codex makes those hooks fail with
exit code 127. The plugin may remain enabled in Claude Code.

The complete `~/.codex/config.toml` stays machine-local because it contains
runtime and per-machine state. Verify the live plugin state with
`codex plugin list`; the Warp entry should report `installed, disabled` until
the plugin publishes a Codex-compatible hook manifest.

## Local Private Config

Do not commit local credentials or work-only exports. Put them in:

```bash
~/.config/zsh/private.zsh
```

Start from `examples/private.zsh.example` when setting up a new machine.

Git and JJ identities are placeholders in the committed files. Copy and edit:

```bash
cp examples/gitconfig-personal.example ~/.gitconfig-personal
cp examples/gitconfig-work.example ~/.gitconfig-work
```

## Explicitly Excluded

- SSH, AWS, Databricks, Docker, Kubernetes, npm, pip, and package registry credentials.
- Shell histories and editor histories.
- Claude/Codex sessions, logs, caches, memories, and per-project state.
- Agent review ledgers, inboxes, event logs, and durable learnings, which can
  contain project-specific context.
- Vendored plugin clones such as Oh My Zsh, oh-my-tmux, and fzf-tab.

Run `./scripts/check-sensitive.sh` before every push.
