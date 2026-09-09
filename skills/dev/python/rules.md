# Python -- language leaf

Python-concrete shapes of the language-agnostic LAWs in
`../engineering/rules.md` (read that first; the numbers below refer to
it). This file exists because rules.md is language-agnostic BY LAW --
the Python idioms live here, not there.

## Project shape and toolchain

- `pyproject.toml` is the single config source (Single Source of Truth).
  `setup.py`, `setup.cfg` and `requirements*.txt` are not a second place
  to declare deps, metadata or tool config; a generated
  `requirements.txt` is an artifact, never the source.
- `src/` layout for a NEW project: with the package under `src/`, an
  import resolves to the INSTALLED package, so a broken `pyproject.toml`
  fails in the test run instead of being masked by the working
  directory. An existing flat layout is not worth a migration on its
  own.
- **New project: `uv`** (`uv.lock` versioned). It is the default because
  the gate image ships it as a first-class resolver and it is one tool
  for env, lockfile and running.
  **Existing project: keep the manager it already has** -- poetry, pdm
  and pipenv are all shipped by the gate image and all resolve
  correctly. Migrating a working repo to uv is its own change, with its
  own reason; it is not a side effect of touching a module.
- **Never two lockfiles.** The lockfile you commit chooses the manager
  the gate must run, and a lockfile whose manager is missing is a tool
  error (exit 2), not a verdict. A partial or stale lock that disagrees
  with `pyproject.toml` is worse than no lock -- resolve it or commit
  neither.
- Ports are `typing.Protocol` (LAW 8, DDD): the domain depends on the
  Protocol, infrastructure implements it, and the in-memory arm is the
  dev default. A domain module that imports `requests`, a driver, or
  `os.environ` has already broken the boundary.

## Typing

- Public functions fully annotated; `mypy --strict` (or pyright strict)
  is the floor for code you write or touch. It is NOT measured by the
  gate -- running it is your job, and nobody else's.
- A legacy untyped codebase does not get a global loosening. Turn strict
  ON at the root and ratchet the exceptions per module
  (`[[tool.mypy.overrides]]` with an explicit `module = [...]` list),
  then shrink that list. `ignore_errors` at the root is the file-wide
  suppression this leaf forbids, written in TOML.
- `Any` carries an adjacent `# reason:`. A signature typed `Any` in and
  `Any` out documents nothing and checks nothing.
- `@dataclass`, `TypedDict`, `NamedTuple`, `Protocol` over a dict of
  dicts. `dict[str, Any]` crossing a layer boundary is an untyped
  contract wearing a type annotation.

## Suppression and escapes (LAW 16)

- Suppression is per line and names the code, with the reason on the
  same line: `# noqa: E501  # reason: ...`,
  `# type: ignore[arg-type]  # reason: ...`. A bare `# noqa` /
  `# type: ignore` also silences the DIFFERENT error that arrives on
  that line tomorrow.
- File-wide `# ruff: noqa`, `# flake8: noqa`, `# mypy: ignore-errors`
  and `[tool.mypy] ignore_errors` erase today's finding AND pre-approve
  every future violation in the file. The gate's hygiene scan fails the
  file-level `noqa` forms outright.
- `typing.cast(...)` is an unchecked cast: it changes what the checker
  believes, never what the object is. Write the invariant that makes it
  true, same as any safety escape.
- `assert` is not validation -- `python -O` strips it. Assert in tests;
  in production raise the typed error.

## Swallowed errors (LAW 18)

- `except: pass`, `except Exception: pass` and
  `contextlib.suppress(...)` require an adjacent
  `# intentional: <reason>`. Without it, "swallowed defect" and
  "deliberate discard" are indistinguishable in an audit, so the bare
  form reads as the defect.
- A bare `except:` also swallows `KeyboardInterrupt` and `SystemExit`.
  Catch `Exception` at minimum, and in practice the narrowest type that
  can actually be raised there.
- Returning a plausible default when the source failed (a hardcoded rate
  table after a network error, an empty dict after a parse error) is
  LAW 4's silent fallback wearing an `except` block -- the caller cannot
  tell a real answer from a fabricated one.
- Library/domain layers never `print()` as error handling: raise a typed
  error from a module-level hierarchy (`class FeedError(Exception)` and
  its subclasses, LAW 7) or emit `logging`; the edge decides
  presentation. `logging` in a library is correct, `print` is a layering
  violation.
- An exception raised inside a `Thread` target dies with the thread and
  the caller sees success. Capture it and re-raise it on the caller's
  side, or the failure is silent by construction.

## Test shapes (LAWs 14, 15, 17)

- pytest only. Fixtures are versioned in the repo or built under
  `tmp_path` / `tmp_path_factory` -- never a path under `$HOME`
  (`Path.home()`, `~/.config/...`), never the developer's real config as
  input. Local-only data gates behind an explicit env var and calls
  `pytest.skip(...)` LOUDLY when absent.
- A versioned fixture is addressed from the test file, not from the
  process: `Path(__file__).parent / "fixtures" / ...`. A relative
  `tests/fixtures/x.json` is resolved against the CURRENT DIRECTORY, so
  it passes from the repo root and fails from anywhere else -- the same
  machine-dependence as a `$HOME` path, one step better hidden.
- `assert result` / `assert x is not None` with no assertion on the
  VALUE is a success-only assert (LAW 15): it passes for a function that
  successfully returns garbage.
- `try: f() ... except SomeError: pass` does not test that the error is
  raised -- it also passes when NOTHING is raised. Use
  `with pytest.raises(SomeError):` and assert on the message or type.
- `@pytest.mark.skip` on a currently-failing test silences a known
  regression. Use `@pytest.mark.xfail(strict=True, reason=...)` -- the
  build fails the day it starts passing, which is the xfail list LAW 15
  requires.
- `time.sleep()` to "let the thread/task finish" is a scheduled race
  (LAW 17). Wait on the real signal: `Event.wait(timeout)`,
  `Thread.join(timeout)`, `Queue.get(timeout=...)`,
  `asyncio.wait_for(...)`, or a bounded poll with a deadline.
- Coverage is a gate metric: a test written to move the percentage
  without asserting behavior is LAW 15's lie with a number attached.

## Concurrency (LAW 12)

- Independent work items get `ThreadPoolExecutor` (I/O bound),
  `ProcessPoolExecutor` (CPU bound), or `asyncio.gather` behind a
  bounded `Semaphore` -- concurrent by default, `max_workers > 1`. The
  GIL is not a reason to ship a serial loop over I/O-bound items.
- Module-level mutable state (a dict used as a cache, a global client)
  is shared across workers and across tests. Own it in an object passed
  in, not in the module.

## Quality gate (the `python` image)

Sentinel at the repo root -- `pyproject.toml`, `setup.py`, `setup.cfg`
or `requirements*.txt` -- selects `ghcr.io/xgodev/quality-gate/python`
(see `../engineering/gate.md` to run it).

| Metric | Tool |
|---|---|
| `fmt` | `ruff format --check` |
| `lint` | `ruff check` |
| `build` | `python3 -m compileall` |
| `test` | `pytest` (`FAILED` lines) |
| `complexity` | `radon cc -n C` (cyclomatic >= 11) |
| `coverage` | `pytest --cov` percent |

- **The gate runs ruff with its OWN ruleset (`--config`), so the
  project's `[tool.ruff]` neither relaxes nor tightens the verdict.**
  Configuring `select` in `pyproject.toml` does not change what the gate
  measures; a repo with no ruff config is still measured. Run
  `ruff format` and `ruff check` before the PR -- a session that never
  runs them ships a formatting regression it never saw.
- **A green local ruff run is not the verdict, and a widened
  `line-length` actively manufactures a red one.** The gate formats and
  measures at ITS width; a project configured wider is formatted to a
  shape the gate then reports as unformatted, one `E501` per long line.
  Either leave ruff unconfigured or mirror the gate's `line-length` --
  never widen it, because every line you "fix" locally moves further
  from the verdict.
- To predict the verdict, measure with the gate's ruleset, not yours:
  run the gate (`../engineering/gate.md`), or point ruff at the same
  `ruff.toml` the image uses. Anything else is a style preference
  wearing the costume of a check.
- Per-line `# noqa: CODE` still applies under the gate's ruleset. That
  is precisely why the file-level form is a hygiene failure and the
  per-line form is not.
- Your local ruff and the image's ruff are pinned separately. A local
  run is the fast signal, not the verdict -- when the two disagree, the
  image is right by definition, so re-run the gate rather than arguing
  with it.

## Red flags (first-person; stop and do the rule)

- "requirements.txt plus setup.py is fine, pyproject is ceremony" ->
  one config source; two places to declare a dep is two places to get it
  wrong.
- "I'll drop a `# type: ignore` here to get mypy green before the demo"
  -> LAW 16: name the code, write the reason, or fix the type.
- "`except Exception: pass` -- it cannot really fail here" -> LAW 18:
  the errors that "cannot happen" are the ones that do. Written reason
  or handle it.
- "Return the default rates when the API is down, so it does not crash"
  -> LAW 4: that is a fabricated answer the caller cannot detect.
- "`assert inv` passes, the test is green" -> LAW 15: assert the value,
  not that the call returned.
- "`time.sleep(0.1)` and the thread will be done" -> LAW 17: stable on
  this machine at this load only; wait on the condition.
- "The fixture is right there in my home dir" -> LAW 14: `tmp_path` or
  versioned in the repo.
- "ruff is not configured in this repo, so lint is not part of done" ->
  the gate brings its own ruleset; not configuring it does not opt out.
- "I will set `select` in pyproject so the gate uses my rules" -> it
  does not; the gate passes `--config` with its own file.
- "`ruff check .` passed, lint is done" -> it passed against YOUR
  config. Measure with the gate's ruleset before calling it done.
- "88 columns is cramped, I will set line-length = 100" -> you just
  guaranteed a `fmt` regression plus one `E501` per long line; the gate
  measures at its own width, not yours.
