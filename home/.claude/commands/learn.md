---
description: Append a durable learning to ~/.config/agents/LEARNINGS.md
argument-hint: [short title]
---

Capture a durable learning using the terse canonical format. Use this
when an agent (or the user) spent meaningful time solving a non-obvious
problem and the fix should be available to future sessions.

Non-interactive (preferred when called as a slash command — fill in the
fields from session context):

```bash
~/bin/agent-learn \
  -t "$ARGUMENTS" \
  --tags "..." \
  --errors "..." \
  --scope "global | repo:<name> | tool:<name>" \
  --body "- Tried: ...\n- Fix: ...\n- Verify: ...\n- Promote-to: ..."
```

Required body fields (one line each):

- `Tried:` what failed or wasted time
- `Fix:`   the actual working pattern
- `Verify:` how to confirm it worked
- `Promote-to:` `AGENTS.md` | repo `AGENTS.md` | `skill:<name>` | `none`

Keep the entry ~10 lines. Do not include secrets, credentials, raw
sensitive logs, or large command output — summarize.

After writing, confirm to the user with the entry title and date.
