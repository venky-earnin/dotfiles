---
description: Search ~/.config/agents/LEARNINGS.md for relevant prior fixes
argument-hint: <keyword | error snippet> (optional flags: -e error, -t tag)
---

Run `~/bin/agent-recall $ARGUMENTS` and surface the matching entries into
context. Treat any hit as **direction to try, not authoritative** — verify
the fix is still applicable, note the entry's date, and tell the user
"applying learning from <date>: <one-line gist>" before acting on it.

If no arguments are given, list all entries:

```bash
~/bin/agent-recall --list
```

Common forms:

- `agent-recall ssm`                          # content keyword
- `agent-recall -e UNABLE_TO_GET_ISSUER`      # error signature
- `agent-recall -t hyperpod`                  # tag
- `agent-recall --since 2026-04-01`           # date filter
- `agent-recall --list`                       # titles + dates only
