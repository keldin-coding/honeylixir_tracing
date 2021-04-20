defmodule HoneylixirTracing.Context do
  @moduledoc """
  """

  # Primarily using this to have a separate process own the table
  use GenServer

  alias HoneylixirTracing.{Span, Context}

  defstruct [:span_id, :trace_id, :parent_span_id]

  # In seconds
  @default_ttl 300
  @table_name :honeylixir_tracing_context

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_arg) do
    # We create a public table to prevent a single process being the bottleneck
    # in anticipation of a lot of spans being made. However, all access *should*
    # go through this module though not necesarily the GenServer.

    _ti_d = :ets.new(@table_name, [
      :set,
      :public,
      :named_table
    ])
    {:ok, :ok}
  end

  def add_span(%Span{span_id: span_id} = span) do
    :ets.insert(@table_name, {span_id, ttl(), span})
  end

  def clear_span(%Span{span_id: span_id}) do
    :ets.delete(@table_name, span_id)
  end

  def get_context(id) do
    case :ets.lookup(@table_name, id) do
      [{^id, _ttl, span}] ->
        from_span(span)

      _ ->
        %Context{}
    end
  end

  def from_span(%Span{span_id: span_id, trace_id: trace_id, parent_id: parent_span_id}) do
    %Context{span_id: span_id, trace_id: trace_id, parent_span_id: parent_span_id}
  end

  def from_span(_), do: %Context{}

  def current() do
    Process.get(:current_context, %HoneylixirTracing.Context{})
  end

  def current_parent_span_id do
    current().span_id
  end

  def current_trace_id do
    ctx = current()

    ctx.trace_id || Honeylixir.generate_long_id()
  end

  # Allow this to be configured later
  defp ttl(), do: @default_ttl
end
