#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail=false

forbidden_paths='(^|/)(\.ssh|\.aws|\.gnupg|\.kube|\.databricks|\.docker|\.mcp-auth|\.npmrc|\.pypirc|\.netrc|\.databrickscfg|pip\.conf|\.zsh_history|\.bash_history|\.python_history|\.lesshst|audit\.log|LEARNINGS\.md|INBOX\.md)(/|$)'

if git ls-files --others --cached --exclude-standard | grep -E "$forbidden_paths" >/tmp/dotfiles-forbidden-paths.$$; then
  echo "forbidden paths found:" >&2
  sed 's/^/  /' /tmp/dotfiles-forbidden-paths.$$ >&2
  fail=true
fi
rm -f /tmp/dotfiles-forbidden-paths.$$

secret_patterns=(
  '-----BEGIN (RSA |DSA |EC |OPENSSH |PGP )?PRIVATE KEY-----'
  'AKIA[0-9A-Z]{16}'
  'ASIA[0-9A-Z]{16}'
  'aws_secret_access_key[[:space:]]*='
  'aws_access_key_id[[:space:]]*='
  'DATABRICKS_TOKEN[[:space:]]*='
  'github_pat_[A-Za-z0-9_]{20,}'
  'gh[opsu]_[A-Za-z0-9_]{20,}'
  'sk-[A-Za-z0-9]{20,}'
  'xox[baprs]-[A-Za-z0-9-]{20,}'
  'https://[^[:space:]@]+:[^[:space:]@]+@'
)

for pattern in "${secret_patterns[@]}"; do
  if git grep -n -I --untracked --exclude-standard -E -e "$pattern" -- . ':(exclude)scripts/check-sensitive.sh' >/tmp/dotfiles-secret-matches.$$; then
    echo "sensitive pattern matched: $pattern" >&2
    sed 's/^/  /' /tmp/dotfiles-secret-matches.$$ >&2
    fail=true
  fi
  rm -f /tmp/dotfiles-secret-matches.$$
done

if "$fail"; then
  exit 1
fi

echo "sensitive scan passed"
