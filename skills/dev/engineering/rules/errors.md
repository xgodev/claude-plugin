# Errors, secrets and safety escapes

A group of `../rules.md` (the index -- read it first). LAW numbers are
global; the language leaves cite them. Each rule binds with no
time-pressure, authority, or sunk-cost exception.

## LAWs

4. **No silent fallback / no masking.** An honest, actionable error beats a
   silent substitution that returns a different result. Never mask an
   infra/tool/environment failure as if it were a code result. Fail loud,
   fail specific.
6. **Secrets are never rendered.** No log line, config dump, diagnostic, or
   error message prints a secret value (token, key, password). Redact at
   the source -- mark the field hidden so the rendered value is `****`
   while the in-memory value stays real. A secret in a log is a leak even
   if the log is "private". Enable config/diagnostic visibility freely;
   just make the secret fields self-mask.
7. **Errors keep their classification to the edge.** Use typed/semantic
   errors that the transport edge (HTTP/gRPC/GraphQL) maps to a code.
   Never wrap an error in a way that erases the type the edge matches on
   -- a generic string wrap that turns a NotFound into a 500 is a defect,
   not a cosmetic one. Propagate the typed error; add context only with a
   wrapper that preserves the classification (and the language's own
   error matching -- type checks, unwrap chains).
16. **Every safety escape carries its written invariant.** An escape hatch
    from the language's safety model (an unsafe block, an unchecked cast,
    a type-checker suppression) transfers a proof obligation from the
    compiler to YOU. Write the invariant that makes it sound in an
    adjacent comment, or the obligation is silently lost -- the next
    maintainer cannot tell whether a change breaks it. The most dangerous
    form is the unaudited concurrency-safety promise: declaring a type
    safe to share across threads by fiat, written by reflex to silence
    the compiler, moving a data race from compile error to production
    heisenbug. A blanket promise over ANY type parameter is a defect on
    its face. A codebase with many escapes and few written invariants has
    an unaudited core. The per-language shapes live in the language
    leaves, not here.
18. **No swallowed errors; low layers return errors, they don't print.**
    Discarding an error (a dropped result, an empty `catch {}`,
    `except: pass`, `_ = err`) requires an adjacent
    `// intentional: <reason>` comment -- without it, "swallowed defect" and
    "deliberate discard" are indistinguishable in an audit, so the bare
    form reads as a genuine smell. A library/core layer never uses
    stdout/stderr prints as error handling -- it returns the typed error
    (LAW 7) or emits structured logging, and the EDGE decides how to
    surface it. A swallowed error turns a real failure into silent wrong
    behavior discovered far away; a deep-layer print is unstructured and a
    layering violation at once.

## Rationalizations -- and the reality

Populated from real subagent output under combined time + sunk-cost +
authority + exhaustion pressure (RED phase). If you catch yourself forming
one of these, you are about to violate a rule. Stop.

| Excuse (verbatim pattern) | Reality |
|---|---|
| "The checker is being conservative, suppressing it here is obviously fine" | "Obviously" is exactly what the missing written invariant was supposed to prove (LAW 16). An unaudited safety promise moves the defect from compile error to production heisenbug. |
| "Logging the error to stderr here IS handling it" | A deep layer printing to stderr is unstructured noise the caller cannot act on (LAW 18). Return the typed error; the edge decides presentation. |

## Red Flags -- STOP

First-person thoughts that mean you are mid-violation. Each maps to the rule it breaks. If you think it, stop and do the rule instead.

- "I'll fall back to a default so it doesn't error" -> LAW 4 (no silent
  masking).
- "Suppress the checker, it is just being strict" -> LAW 16 (write the
  invariant or you have an unaudited safety promise).
- "Discard the error and keep going, it can't really happen" -> LAW 18
  (discards carry a written reason; errors that "can't happen" are the
  ones that do).
