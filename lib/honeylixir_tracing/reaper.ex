defmodule HoneylixirTracing.Reaper do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(args) do
    state = %{
      interval: Keyword.get(args, :interval, reaper_interval() * 1000)
    }

    Process.send_after(self(), :reap, state.interval)

    {:ok, state}
  end

  def handle_info(:reap, %{interval: interval} = state) do
    Process.send_after(self(), :reap, interval)

    :telemetry.span(
      [:honeylixir_tracing, :reaper],
      %{},
      fn ->
        current = System.monotonic_time(:millisecond)

        num_removed =
          :ets.select_delete(
            :honeylixir_tracing_context,
            [{{:_, :"$1", :_}, [{:<, :"$1", {:const, current}}], [true]}]
          )

        {:ok, %{removed_span_count: num_removed}}
      end
    )

    {:noreply, state}
  end

  defp reaper_interval(), do: Application.get_env(:honeylixir_tracing, :reaper_interval_sec, 60)
end
