**REQUIRED BACKGROUND:** `references/model-errors.md` — `HTTPStatusFor` maps a boost error `Kind` to the HTTP status this package uses.

```go
import "github.com/xgodev/boost/model/restresponse"
```

(Import path is `model/restresponse`; the Go package name is `response`.)

## Error response envelope

```go
type Error struct {
    HttpStatusCode int
    ErrorCode      string                 `json:",omitempty"`
    Message        string
    Info           string                 `json:",omitempty"`
    AdditionalInfo []AdditionalInfoError  `json:",omitempty"`
}

type AdditionalInfoError struct {
    Key   string `json:"errorCode"`
    Value string `json:"message"`
}
```

For request validation failures (HTTP 422), use the constructor instead of building `Error` by hand:

```go
type ValidationError struct {
    FieldName string
    Message   string
}

type UnprocessableEntityError struct {
    Error            // embedded
    ValidationErrors []ValidationError
}

func NewUnprocessableEntity(err validator.ValidationErrors) UnprocessableEntityError
```

```go
if err := c.Bind(&req); err != nil {
    return c.JSON(http.StatusBadRequest, err)
}
if err := c.Validate(&req); err != nil {
    respErr := restresponse.NewUnprocessableEntity(err.(validator.ValidationErrors))
    return c.JSON(respErr.HttpStatusCode, respErr)
}
```

For everything else — a boost typed error already carries its own kind, so route it through the error handler (see `references/model-errors.md`) rather than constructing `Error` manually; `HTTPStatusFor(kind errors.Kind) int` is what the Echo/gRPC/function edges call to pick the status code.

## Health response

Builds on `extra/health` — see `references/extra/health.md` for registering checkers. This package turns the registered checks into the actual HTTP response:

```go
func NewHealth(ctx context.Context) (Health, int)   // runs health.CheckAll, returns body + status (200/207/503)

type Health struct {
    Status  HealthStatus    // Ok | Partial | Down
    Details []HealthDetail
}

type HealthDetail struct {
    Status      HealthStatus
    Name        string
    Description string
    Error       string `json:",omitempty"`
}
```

```go
srv.GET("/readyz", func(c echo.Context) error {
    health, statusCode := restresponse.NewHealth(c.Request().Context())
    return c.JSON(statusCode, health)
})
```

## Resource status (build info)

```go
func NewResourceStatus() ResourceStatusResponse

type ResourceStatusResponse struct {
    ApplicationName       string
    ImplementationVersion string
    ImplementationBuild   string
    CommitSHA             string
    BuildDate             string
}
```

Populated from package-level vars (`AppName`, `Version`, `BuildVersion`, `CommitSHA`, `BuildDate`) set at build time via linker flags (`-ldflags "-X ..."`) — not something you set at runtime.

```go
srv.GET("/status", func(c echo.Context) error {
    return c.JSON(http.StatusOK, restresponse.NewResourceStatus())
})
```

## Red flags

| Red flag | Fix |
|---|---|
| Hand-building a JSON error map instead of `Error` / `NewUnprocessableEntity` | Use the typed structs so every endpoint returns the same error shape |
| Calling `health.CheckAll` directly and building the JSON response by hand | `restresponse.NewHealth(ctx)` already derives status + body |
| Setting `ResourceStatusResponse` fields at runtime | They come from build-time linker flags on the package vars, not a constructor argument |
| Returning a boost typed error's message directly instead of through the error handler | Let the Echo/gRPC/function edge call `HTTPStatusFor` via `Classify` — don't shortcut it |
