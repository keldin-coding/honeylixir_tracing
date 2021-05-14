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
    {:plug, ">= 1.9.0"}
  ]
```

2. Configure the integration:
```elixir
config :honeylixir_tracing, integrations: %{plug: true}
```

3. Include the `HoneylixirTracing.Integrations.Plug` in your plug pipeline as early as possible.

## Ecto

Uses `:telemetry` events to create spans for Ecto queries.

### Using

1. Ensure `ecto` is one of your dependencies
2. Configure the integration:
```elixir
config :honeylixir_tracing, integrations: %{ecto: [repo_name: :my_app]}
```

You can provide either `repo_name` or `event_prefix` as configuration. Based on Ecto documentation, providing
only `:repo_name` assumes that the full event is `[:my_app, :repo, :query]`. Providing an `:event_prefix` should
be a list that `[:query]` can be appended to.
