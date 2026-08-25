# Eve Software Factory (MVP)

AgentPack that implements a simple relay-chain "software factory":

PM -> Planner -> Coder -> Verifier -> PR

This repo is intended to be installed into an Eve project via `x-eve.packs`,
then used through chat routing (messages starting with `factory ...`).

## Install

Pin the public pack to a full commit SHA so project sync and its lockfile are
reproducible:

```yaml
x-eve:
  packs:
    - source: eve-horizon/eve-software-factory
      ref: 72ed321b9dee7ae497e7ff60486aa2e8657d365f
```

The pinned revision above is anonymously fetchable and passes this repository's
AgentPack validation. Upgrade it deliberately when adopting a newer pack
revision.

## Local development override

When changing the pack alongside a consumer checkout, replace the remote entry
temporarily with an explicit sibling path:

```yaml
x-eve:
  packs:
    - source: ../eve-software-factory
```

Then re-sync:

```bash
eve agents sync --project <PROJECT_ID> --ref main --repo-dir . --allow-dirty --local
```

Restore a pinned public source before publishing a consumer repository.

## What's Included

- `eve/pack.yaml`: pack descriptor
- `eve/agents.yaml`: four factory agents
- `eve/teams.yaml`: one relay team (`factory`)
- `eve/chat.yaml`: one route (`^factory\\b`)
- `eve/x-eve.yaml`: harness profiles + defaults
- `skills/`: OpenSkills `SKILL.md` instructions and templates

## Validate

```bash
ruby scripts/validate-agentpack.rb
```

CI runs the same structural and reference checks, then anonymously fetches the
pinned public revision and validates the materialised pack without GitHub
credentials.
