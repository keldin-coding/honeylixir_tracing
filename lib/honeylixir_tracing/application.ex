defmodule HoneylixirTracing.Application do
  @moduledoc false

  use Application

  # @known_integrations %{plug: []}

  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  defp children do
    [
      HoneylixirTracing.Context
    ] ++ death_the_kid() ++ plug_integration()
  end

  defp death_the_kid() do
    if Application.get_env(:honeylixir_tracing, :_start_reaper, true),
      do: [{HoneylixirTracing.Reaper, []}],
      else: []
  end

  defp plug_integration() do
    case Map.get(integration_configs(), :plug) do
      true ->
        [{HoneylixirTracing.Integrations.PlugTracker, []}]

      _ ->
        []
    end
  end

  defp integration_configs(), do: Application.get_env(:honeylixir_tracing, :integrations, %{})
end
