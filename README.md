# claude-plugin

Claude Code plugin that bundles the **quality-gate** skill: it invokes the
shared [Quality Gate](https://github.com/xgodev/quality-gate) dispatcher
locally before you open a PR, interprets the JSON verdict, and renders an
analyzed result.

The gate itself lives in a separate repository
([`xgodev/quality-gate`](https://github.com/xgodev/quality-gate)) and is
cloned into `~/.quality-gate/` on first use. The gate runs **identically**
locally and in CI: it fails **only** when a PR worsens a metric relative to a
chosen base ref.

## Install

```text
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install claude-plugin
```

## Usage

Once installed, ask Claude to run the quality gate before opening a PR
(e.g. "run quality gate", "rodar QG", "check quality before PR"). The skill
will ensure the gate is cloned/updated and run it against your project.

Override the gate location for local gate development with the `QG_PATH`
environment variable.

## Documentation

See [`docs/quality-gate.md`](docs/quality-gate.md) for the full skill
contract, environment variables, and behavior.

## License

See the gate repository for details.
