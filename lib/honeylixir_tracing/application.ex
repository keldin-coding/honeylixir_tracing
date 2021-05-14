defmodule HoneylixirTracing.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    ecto_integration()

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

  defp ecto_integration() do
    case Map.get(integration_configs(), :ecto) do
      true ->
        raise """
          HoneylixirTracing cannot accept only `true` for this integration.
          You must provide either :repo_name or :event_prefix as a config value.
          You can configure it by doing
          config :honeylixir_tracing, integrations: %{ecto: [repo_name: :awesome_app]}
        """

      opts when is_list(opts) ->
        HoneylixirTracing.Integrations.Ecto.setup(opts)

      opts when not is_nil(opts) ->
        raise """
          Please provide a Keyword list of configuration as documented for this integration.
        """

      _ ->
        nil
    end
  end

  defp integration_configs(), do: Application.get_env(:honeylixir_tracing, :integrations, %{})
end
