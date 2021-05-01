defmodule HoneylixirTracing.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  defp children do
    [
      HoneylixirTracing.Context,
      HoneylixirTracing.TraceFields
    ] ++ death_the_kid()
  end

  defp death_the_kid() do
    if Application.get_env(:honeylixir_tracing, :_start_reaper, true),
      do: [{HoneylixirTracing.Reaper, []}],
      else: []
  end
end
