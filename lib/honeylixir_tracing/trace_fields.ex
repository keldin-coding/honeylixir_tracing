defmodule HoneylixirTracing.TraceFields do
  @moduledoc false

  use GenServer
  alias HoneylixirTracing.Context

  @table_name :honeylixir_tracing_trace_fields

  def init(_) do
    _t_id =
      :ets.new(@table_name, [
        :set,
        :public,
        :named_table
      ])

    {:ok, :ok}
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def cleanup_trace(trace_id) do
    GenServer.cast(__MODULE__, {:cleanup_trace, trace_id})
  end

  def handle_cast({:cleanup_trace, trace_id}, _state) do
    if !Context.any_spans_for_trace?(trace_id) do
      :ets.delete(@table_name, trace_id)
    end

    {:noreply, :ok}
  end

  def add_trace_field_data(trace_id, fields) when is_binary(trace_id) and is_map(fields) do
    old_data = lookup_trace_fields(trace_id)

    :ets.insert(@table_name, {trace_id, Map.merge(old_data, fields)})
  end

  def lookup_trace_fields(trace_id) when is_binary(trace_id) do
    case :ets.lookup(@table_name, trace_id) do
      [{^trace_id, fields}] ->
        fields

      _ ->
        %{}
    end
  end
end
