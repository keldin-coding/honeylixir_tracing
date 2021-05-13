# Built-in Integrations

HoneylixirTracing includes a few built-in instrumenters for common libraries. These
can be configured in regular application configuration using a map of integrations.

```elixir
config :honeylixir_tracing, integrations: %{}
```

For any of the integrations, setting `name => true` (e.g. `%{plug: true}`) will enable
the integration and use any defaults for the built-in integration.

## Plug

Wraps a plug pipeline in a span to handle most standard cases. The integration also monitors
for when a request process unexpectedly dies and ends the span. There may be orphaned spans
as a result of that, but you should get the error span at least. We attempt to serialize
the `reason` given via `f:Process.monitor/1`.

### Using

Enabling the plug integration requires three:

1. Ensure `plug` is included as a dependency.
```elixir
def deps do
  [
    {:plug, ">= 1.0"}
  ]
```

2. Configure the integration:
```elixir
config :honeylixir_tracing, integrations: %{plug: true}
```

3. Include the `HoneylixirTracing.Integrations.Plug` in your plug pipeline as early as possible.
