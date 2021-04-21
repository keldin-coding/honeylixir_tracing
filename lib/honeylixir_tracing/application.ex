defmodule HoneylixirTracing.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  defp children do
    [
      HoneylixirTracing.Context
    ]
  end
end
