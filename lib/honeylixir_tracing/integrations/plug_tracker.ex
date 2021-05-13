defmodule HoneylixirTracing.Integrations.PlugTracker do
  @moduledoc false

  # Server used to monitor plug request pids for unexpected termination.

  # In theory, this server could be reused to monitor *any* async spans that may
  # abort unexpectedly and send them. However, it would need some passable configuration
  # to be able to add useful fields.
  use GenServer
  alias HoneylixirTracing.{Context, Span}

  def start_link(args) do
    unless Code.ensure_loaded?(Plug.Conn) do
      raise "You must depend on `plug` in mix.exs in order to use this"
    end

    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(_args) do
    {:ok, %{}}
  end

  def register(pid, span_key) do
    GenServer.call(__MODULE__, {:register, pid, span_key})
  end

  def finalize(ref) do
    GenServer.call(__MODULE__, {:finalize, ref})
  end

  def handle_call({:register, pid, span_key}, _from, state) do
    ref = Process.monitor(pid)
    {:reply, ref, Map.put(state, ref, span_key)}
  end

  def handle_call({:finalize, ref}, _from, state) do
    Process.demonitor(ref)
    {:reply, true, Map.delete(state, ref)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    with {:ok, span_key} <- Map.fetch(state, ref),
         span when not is_nil(span) <- Context.lookup_span(span_key) do
      encodable_reason =
        case Jason.encode(reason) do
          {:ok, _encoded} -> reason
          _ -> :unknown
        end

      span
      |> Span.add_field_data(%{
        "response.status_code" => "unknown",
        "meta.elixir.process_down_reason" => encodable_reason
      })
      |> Span.send()

      Context.clear_span(span)
    end

    {:noreply, Map.delete(state, ref)}
  end
end
