# Go -- language leaf

Go-concrete shapes of the language-agnostic LAWs in
`../engineering/rules.md` (read that first; numbers below refer to it),
plus the routes to Go frameworks. This file exists because rules.md is
language-agnostic BY LAW -- the Go idioms live here, not there.

## Routes

| Context | Reference |
|---|---|
| github.com/xgodev/boost -- the Go service framework (any boost import, boot/wiring, factories, adapters) | `boost/index.md` (an index; its factory rows route on through group indexes -- follow them to the terminal reference) |

## Errors (LAWs 18, 7, 4)

- `_ = err` requires an adjacent `// intentional: <reason>` -- a bare
  discard is indistinguishable from a swallowed defect. `errcheck` (via
  golangci-lint) exists to catch exactly these; do not silence it
  file-wide.
- Libraries return errors; they do not `fmt.Println`/`log.Fatal` as
  handling. `log.Fatal` in a library kills the caller's process --
  that decision belongs to `main`.
- Wrap with `%w` so `errors.Is`/`errors.As` keep matching (LAW 7);
  a `fmt.Errorf("failed: %v", err)` wrap erases the type the edge
  matches on.

## Tests (LAWs 14, 15, 17)

- Fixtures: versioned in the repo or created under `t.TempDir()` --
  never a path under the developer's `$HOME`, never the dev's real
  config as input. Local-only data gates behind an explicit env var and
  skips loudly (`t.Skipf`) when absent.
- `time.Sleep` is never synchronisation (LAW 17): wait on a channel,
  `sync.WaitGroup`, `context.WithTimeout`, or a bounded poll with a
  deadline. A test that sleeps "so the goroutine finishes" is a
  scheduled race.
- `err == nil` alone is a success-only assert (LAW 15) -- assert the
  VALUE too.
- `t.Skip` on a currently-failing test silences a known regression --
  xfail list that alarms on pass, never a skip.

## Suppression and escapes (LAW 16)

- `//nolint` is per-line, names the linter (`//nolint:errcheck`), and
  carries a reason on the same line. A file-wide or bare `//nolint`
  pre-approves every future violation in scope.
- `unsafe.Pointer` and `//go:linkname` carry the written invariant that
  makes them sound, same as any safety escape.

## Concurrency (LAW 12)

- Independent work items get a bounded worker pool (`errgroup` with
  `SetLimit`, or channel-fed workers) from line one, concurrent by
  default. Shared state is either owned by one goroutine (channels) or
  guarded -- run `-race` in tests always.
