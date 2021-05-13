defmodule HoneylixirTracing.Application do
  @moduledoc false

  use Application

  @known_integrations %{plug: HoneylixirTracing.Integrations.Plug}

  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  defp children do
    [
      HoneylixirTracing.Context
    ] ++ death_the_kid() ++ integrations_children()
  end

  defp death_the_kid() do
    if Application.get_env(:honeylixir_tracing, :_start_reaper, true),
      do: [{HoneylixirTracing.Reaper, []}],
      else: []
  end

  defp integrations_children() do
    integrations = Application.get_env(:honeylixir_tracing, :integrations, %{})

    Enum.reduce(@known_integrations, [], fn {name, module}, acc ->
      case Map.get(integrations, name, nil) do
        true -> [{module, []} | acc]
        opts when is_list(opts) -> [{module, opts} | acc]
        nil -> acc
      end
    end)
  end
end
