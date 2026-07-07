**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

```go
import language "github.com/xgodev/boost/factory/contrib/golang.org/x/text/v0/language"

// Default language tag (cached, singleton)
defaultTag, err := language.DefaultTag()
if err != nil { log.Fatalf("language: %v", err) }

// Store a per-request language on the context
ctx, err := language.ToContext(context.Background(), "pt-BR")
if err != nil { log.Fatalf("language: %v", err) }

// Read it back — falls back to the default if none was set
tag, err := language.FromContext(ctx)
if err != nil { log.Fatalf("language: %v", err) }
```

Wraps `golang.org/x/text/language` to parse and validate BCP 47 language tags. Default language: `boost.factory.language.default` (override `BOOST_FACTORY_LANGUAGE_DEFAULT`, defaults to `"en-US"`). Context key name used to store the per-request language: `boost.factory.language.userKey` (override `BOOST_FACTORY_LANGUAGE_USERKEY`, defaults to `"userLang"`).

## Exported functions

| Function | Signature | Purpose |
|---|---|---|
| `DefaultTag` | `func() (language.Tag, error)` | Cached, parsed default tag |
| `Default` | `func() string` | Default language as a raw string |
| `UserKey` | `func() string` | Context key name for the per-request language |
| `ToContext` | `func(ctx context.Context, lang string) (context.Context, error)` | Parses and validates `lang`, stores it under `UserKey` |
| `FromContext` | `func(ctx context.Context) (language.Tag, error)` | Reads the tag from context; falls back to `DefaultTag()` if unset |

## Red flags

| Red flag | Fix |
|---|---|
| `language.Parse(lang)` from the upstream package directly in a handler, no error handling | `language.ToContext(ctx, lang)` — validates and stores in one call |
| Reading the user's language without a fallback path | `language.FromContext(ctx)` already falls back to the default |
| Hardcoded language strings scattered through the codebase | Read from `boost.factory.language.default` config, not a literal |
| Storing the language as a raw string on the context under an ad-hoc key | Use `ToContext`/`FromContext` so the key name stays centralized and configurable |
