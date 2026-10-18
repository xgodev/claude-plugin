**REQUIRED BACKGROUND:** `references/start.md`, `references/wrapper/config.md`.

MCP (Model Context Protocol) server and client on the official SDK
`github.com/modelcontextprotocol/go-sdk` (`mcp` package). Never call
`mcp.NewServer` / `mcp.NewClient` / `Connect` by hand -- go through the factory.

## Canonical examples (ship with boost)

- `factory/contrib/modelcontextprotocol/go-sdk/v1/server/examples/greet/` -- one typed tool over streamable HTTP
- `factory/contrib/modelcontextprotocol/go-sdk/v1/client/examples/greet/` -- calls it

## Two halves

| Path | Root | When |
|---|---|---|
| `factory/contrib/modelcontextprotocol/go-sdk/v1/server/` | `boost.factory.mcp.server` | Expose tools/prompts/resources to an agent |
| `factory/contrib/modelcontextprotocol/go-sdk/v1/client/` | `boost.factory.mcp.client` | Call another MCP server |

```go
boost.Start()

srv, err := server.NewServer(ctx, mcplog.Register, otel.Register)
if err != nil {
    return err
}
mcp.AddTool(srv.Instance(), &mcp.Tool{Name: "greet", Description: "says hello"}, greet)
srv.Serve(ctx)

cli, err := client.NewClient(ctx, mcplog.Register, otel.Register) // connects
if err != nil {
    return err
}
defer cli.Close()
res, err := cli.Session().CallTool(ctx, &mcp.CallToolParams{Name: "greet", Arguments: map[string]any{"name": "boost"}})
```

- Server: `Instance()` (`*mcp.Server`, register tools on it), `Handler()` (streamable HTTP handler to mount on echo/net-http), `Serve`/`Shutdown` (a `multiserver.Server`).
- Client: the constructor connects; `Session()` (`*mcp.ClientSession`), `Instance()`, `Close()`.
- A second server/upstream: `NewServerWithConfigPath(ctx, "boost.factory.mcp.server.admin")` / `NewClientWithConfigPath(ctx, "boost.factory.mcp.client.github")` -- unset keys fall back to the root defaults.

## Keys

Server (`BOOST_FACTORY_MCP_SERVER_*`): `name` (empty = `boost.applicationName`),
`version` (empty = main module version stamped by `go build`, `0.0.0` when unstamped), `instructions`, `transport` (`HTTP` | `STDIO`), `port`
(`8090`), `path` (`/mcp`), `stateless`, `jsonResponse`, `sessionTimeout`,
`keepAlive`.

Client (`BOOST_FACTORY_MCP_CLIENT_*`): `name`, `version` (same default), `transport` (`HTTP` |
`COMMAND`), `endpoint` (`http://localhost:8090/mcp`), `maxRetries` (`5`,
negative disables), `command`, `args`, `keepAlive`.

camelCase keys take a double underscore in env: `BOOST_FACTORY_MCP_SERVER_JSON__RESPONSE`.

## Plugins

Same shape on both sides; each has its own `.enabled` under `<root>.plugins`.

| Plugin | Server | Client | What it does |
|---|---|---|---|
| Log | `.../server/plugins/local/wrapper/log` | `.../client/plugins/local/wrapper/log` | method, tool, duration, error via `wrapper/log`; `.log.level` for success (errors at ERROR) |
| OpenTelemetry | `.../server/plugins/contrib/go.opentelemetry.io/otel/v1` | `.../client/plugins/contrib/go.opentelemetry.io/otel/v1` | span per call from the boost otel factory; trace context travels in `params._meta` (client injects, server extracts) |

Client plugins run **before** `Connect`, so `initialize` is logged/traced too.

## fx

| Module | Provides |
|---|---|
| `fx/modules/factory/contrib/modelcontextprotocol/go-sdk/v1/server` | `*server.Server`, `*mcp.Server`; joins the multiserver group; takes `[]server.Plugin` |
| `fx/modules/factory/contrib/modelcontextprotocol/go-sdk/v1/client` | `*client.Client`, `*mcp.ClientSession`; closes on stop; takes `[]client.Plugin` |

## Testing

Use `mcp.NewInMemoryTransports()` with `srv.Instance().Connect(ctx, st, nil)`,
or an `httptest.Server` around `mcp.NewStreamableHTTPHandler` and the client
factory with `Endpoint: ts.URL, MaxRetries: -1`.

## Red flags

| Red flag | Fix |
|---|---|
| `mcp.NewServer(...)` / `mcp.NewClient(...)` in app code | Use the factory so config, plugins and lifecycle are wired |
| Hand-written `http.ListenAndServe` for the MCP endpoint | `srv.Serve(ctx)`, or mount `srv.Handler()` on the existing echo server |
| Propagating trace headers by hand | Register the otel plugin on both sides -- it uses `_meta` |
| Client constructed per request | Build once (fx module), reuse `Session()` |
