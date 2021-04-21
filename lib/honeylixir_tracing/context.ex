defmodule HoneylixirTracing.Context do
  @moduledoc """
  """

  # Primarily using this to have a separate process own the table
  use GenServer

  alias HoneylixirTracing.Span

  # In seconds
  @default_ttl 300
  @table_name :honeylixir_tracing_context
  @context_key :honeylixir_context

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_arg) do
    # We create a public table to prevent a single process being the bottleneck
    # in anticipation of a lot of spans being made. However, all access *should*
    # go through this module though not necesarily the GenServer.

    _t_id =
      :ets.new(@table_name, [
        :set,
        :public,
        :named_table
      ])

    {:ok, :ok}
  end

  @spec set_current_span(Span.t()) :: :ok | nil
  def set_current_span(%Span{} = span) do
    if add_span(span) do
      context = Process.get(@context_key, [])
      Process.put(@context_key, [span | context])
      :ok
    end
  end

  @spec set_current_span({String.t(), String.t()}) :: :ok | nil
  def set_current_span({trace_id, span_id}) do
    case :ets.lookup(@table_name, {trace_id, span_id}) do
      [{{^trace_id, ^span_id}, _ttl, %Span{} = span}] ->
        context = Process.get(@context_key, [])
        Process.put(@context_key, [span | context])
        :ok

      _ ->
        nil
    end
  end

  @spec current_span() :: nil | HoneylixirTracing.Span.t()
  def current_span() do
    @context_key
    |> Process.get([])
    |> Enum.at(0)
  end

  @spec clear_current_span() :: none()
  def clear_current_span() do
    {current_span, remaining} = List.pop_at(current_context(), 0)
    clear_span(current_span)
    Process.put(@context_key, remaining)
  end

  @spec current_span_id() :: String.t() | nil
  def current_span_id() do
    if current_span = current_span(), do: current_span.span_id, else: nil
  end

  @spec current_trace_id() :: String.t() | nil
  def current_trace_id do
    if current_span = current_span(), do: current_span.trace_id, else: nil
  end

  defp add_span(%Span{trace_id: trace_id, span_id: span_id} = span) do
    :ets.insert(@table_name, {{trace_id, span_id}, ttl(), span})
  end

  defp clear_span(%Span{trace_id: trace_id, span_id: span_id}) do
    :ets.delete(@table_name, {trace_id, span_id})
  end

  defp clear_span(_), do: nil

  defp current_context(), do: Process.get(@context_key, [])

  # Allow this to be configured later
  defp ttl(), do: @default_ttl
end
