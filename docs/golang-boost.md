# golang-boost (the `dev` skill's golang leaf)

Claude Code skill set for **[github.com/xgodev/boost](https://github.com/xgodev/boost)** —
the modular Go service framework. A single `boost` entry skill whose small
top-level index expands, group by group, into `references/*.md` (down to a
domain file for `factory/*`, since it alone covers 39 components). Only the
entry skill's tiny index loads on every trigger — every deeper file loads on
demand only when the question actually needs it.

> The skill documents `boost`, but it is **distributed from this repo** as
> part of `claude-plugin`. The boost source code lives in
> [`xgodev/boost`](https://github.com/xgodev/boost).

## Install

`golang-boost` (the `dev` skill's golang leaf) ships as part of the all-in-one
`claude-plugin` -- see the [repo README](../README.md) for install and
update instructions.

## What's inside

```
skills/
  boost/
    SKILL.md                 # entry skill: 8 top-level contexts, ~25 lines
    references/
      start.md, model-errors.md, CONTRIBUTING.md   # inline in the index, no hop
      wrapper.md      -> wrapper/{cache,config,log,log-backends,publisher}.md
      bootstrap.md     -> bootstrap/{function,middleware,adapter-kafka,adapter-nats,adapter-pubsub}.md
      extra.md         -> extra/{health,middleware,multiserver}.md
      fx.md            -> fx/{modules,pluggable-datastore}.md
      factory.md       -> factory/{database,messaging,http,observability,infra}.md
                            -> factory/{ants,aws,...,zerolog}.md   # 39 leaves
```

Navigation depth matches group size: root essentials sit inline in `SKILL.md`
(no hop), the four small groups (wrapper/bootstrap/extra/fx) are one hop away,
and `factory/*` — which alone accounts for 39 of the 58 leaf files — is grouped
by domain first, so a factory question is two hops (context → domain → leaf)
instead of loading a 39-row table every time any factory topic comes up.

- `references/start.md` — boot sequence (`boost.Start()`).
- `references/model-errors.md` — typed error catalog.
- `references/CONTRIBUTING.md` — guide for contributing to boost itself.
- `references/wrapper.md` — log, config, cache, publisher.
- `references/bootstrap.md` — function bootstrap, middleware, Kafka/NATS/Pub-Sub adapters.
- `references/extra.md` — health, extra middleware, multiserver.
- `references/fx.md` — fx modules, pluggable datastore.
- `references/factory.md` — database, messaging, HTTP/RPC, observability, cloud/infra domains, each expanding into its own leaves (Echo, Resty, Mongo, Cassandra, Redis, Kafka, AWS, gRPC, OTel, …).

Run `python3 scripts/verify_references.py` after editing any reference file —
it confirms every `references/....md` pointer in `skills/dev/golang/` still
resolves.

## Maintenance

The `boost` skill co-evolves with the boost framework but lives in this
separate repo. See [`CLAUDE.md`](../CLAUDE.md) for the sync rule: whenever a
boost component changes in `xgodev/boost`, the matching reference file (under
`skills/dev/golang/references/`) must be updated here in a corresponding PR, with
a `plugin.json` version bump.

## License

MIT — see [LICENSE](../LICENSE).
