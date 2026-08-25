# Contributing to the Eve Software Factory

Keep this AgentPack public, deterministic, and consumable by pinned SHA without
a sibling checkout. Changes to agents, teams, routes, profiles, models, or skill
references must preserve the complete relay contract.

The project follows the Eve Horizon
[Code of Conduct](https://github.com/eve-horizon/eve-horizon/blob/main/CODE_OF_CONDUCT.md).
Sign off contributions under the
[Developer Certificate of Origin](https://developercertificate.org/) with
`git commit -s`.

Before opening a pull request, run:

```bash
ruby scripts/validate-agentpack.rb
```

Do not add private repositories, credentials, deployment IDs, or unpinned
consumer examples. Report vulnerabilities privately as described in
[SECURITY.md](SECURITY.md).
