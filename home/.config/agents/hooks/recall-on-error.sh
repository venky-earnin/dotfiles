#!/usr/bin/env bash
# PostToolUse(Bash) hook: recall durable learnings after real command errors.
# Handles known Claude payload fields and exits quietly for unknown payloads.

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
RECALL="$HOME/bin/agent-recall"
[[ -x "$RECALL" ]] || exit 0

payload="$(cat 2>/dev/null || true)"
[[ -n "$payload" ]] || exit 0

tool="$(printf '%s' "$payload" | jq -r '.tool_name // .toolName // .tool // .name // empty' 2>/dev/null)"
if [[ -z "$tool" ]]; then
  exit 0
fi
if [[ "$tool" != "Bash" && "$tool" != "shell" && "$tool" != "exec_command" ]]; then
  exit 0
fi

exit_code="$(printf '%s' "$payload" | jq -r '
  .tool_response.exitCode //
  .tool_response.exit_code //
  .toolResponse.exitCode //
  .toolResponse.exit_code //
  .result.exitCode //
  .result.exit_code //
  .output.exitCode //
  .output.exit_code //
  .exitCode //
  .exit_code //
  empty
' 2>/dev/null)"

[[ "$exit_code" =~ ^[0-9]+$ ]] || exit 0
[[ "$exit_code" -ne 0 ]] || exit 0

output="$(printf '%s' "$payload" | jq -r '
  .tool_response.output //
  .tool_response.stderr //
  .tool_response.stdout //
  .toolResponse.output //
  .toolResponse.stderr //
  .toolResponse.stdout //
  .result.output //
  .result.stderr //
  .result.stdout //
  .output.output //
  .output.stderr //
  .output.stdout //
  .stderr //
  .stdout //
  .message //
  empty
' 2>/dev/null | tail -c 8000)"

[[ -n "$output" ]] || exit 0

sig='traceback|[a-z]+error|[a-z]+exception|fatal:|no such file|command not found|permission denied|out of memory|cannot |refused|not found|segmentation|assertion'
sig_lines="$(printf '%s\n' "$output" | grep -iE "$sig" || true)"
[[ -n "$sig_lines" ]] || exit 0

tokens="$(
  {
    printf '%s\n' "$sig_lines" | grep -oE '[A-Za-z_]+(Error|Exception)'
    printf '%s\n' "$sig_lines" | grep -oE '[A-Z][A-Za-z]{2,5}'
    printf '%s\n' "$sig_lines" | grep -oE '[A-Za-z][A-Za-z0-9_]{4,}'
  } 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u |
    grep -vxE 'error|errors|exception|traceback|failed|fatal|python|command|found|permission|cannot|recent|during|object|module|runtime|became|before|after|while|which|there|these|those|value|values|result|results|output|caller|called|please|should|expected|received|return|returned|warning|invalid|missing' |
    head -12
)"
[[ -n "$tokens" ]] || exit 0

hits=""
seen=""
count=0
tries=0
while IFS= read -r tok; do
  [[ -n "$tok" ]] || continue
  tries=$((tries + 1))
  [[ "$tries" -gt 6 ]] && break
  res="$("$RECALL" -e "$tok" --limit 2 2>/dev/null || true)"
  [[ -n "$res" ]] || continue
  hdr="$(printf '%s\n' "$res" | grep -m1 '^### ' || true)"
  case "$seen" in *"$hdr"*) continue ;; esac
  seen="$seen|$hdr"
  hits="${hits}${res}"$'\n'
  count=$((count + 1))
  [[ "$count" -ge 3 ]] && break
done <<<"$tokens"

[[ -n "$hits" ]] || exit 0

ctx="[auto-recall] A shell command exited ${exit_code}. Prior LEARNINGS.md entries may apply. Treat them as hints, verify, and note the date:

$(printf '%s' "$hits" | head -c 4000)"

python3 -c '
import json
import sys

print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": sys.stdin.read(),
  },
  "suppressOutput": True,
}))
' <<<"$ctx"
