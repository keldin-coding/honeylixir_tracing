defmodule HoneylixirTracing.Context do
  @moduledoc false

  # Primarily using this to have a separate process own the table
  use GenServer

  alias HoneylixirTracing.Span

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

  @spec set_current_span(Span.t() | {String.t(), String.t()}) :: {:ok, nil | Span.t()}
  @spec set_current_span(any()) :: {:ok, nil}
  def set_current_span(%Span{} = span) do
    if add_span(span) do
      {:ok, Process.put(@context_key, span)}
    else
      {:ok, nil}
    end
  end

  def set_current_span({trace_id, span_id} = key)
      when is_binary(trace_id) and is_binary(span_id) do
    case lookup_span(key) do
      %Span{} = span ->
        {:ok, Process.put(@context_key, span)}

      _ ->
        {:ok, nil}
    end
  end

  def set_current_span(nil) do
    {:ok, Process.put(@context_key, nil)}
  end

  def set_current_span(_), do: {:ok, nil}

  @spec current_span() :: HoneylixirTracing.Span.t() | nil
  def current_span(), do: Process.get(@context_key)

  @spec current_span_id() :: String.t() | nil
  def current_span_id() do
    if current_span = current_span(), do: current_span.span_id, else: nil
  end

  @spec current_trace_id() :: String.t() | nil
  def current_trace_id do
    if current_span = current_span(), do: current_span.trace_id, else: nil
  end

  def add_span(%Span{trace_id: trace_id, span_id: span_id} = span)
      when is_binary(trace_id) and is_binary(span_id) do
    :ets.insert(
      @table_name,
      {{trace_id, span_id}, System.monotonic_time(:millisecond) + ttl(), span}
    )
  end

  def add_span(_), do: false

  def clear_span(%Span{trace_id: trace_id, span_id: span_id}) do
    :ets.delete(@table_name, {trace_id, span_id})
  end

  def clear_span(_), do: nil

  def lookup_span(%Span{trace_id: trace_id, span_id: span_id}) do
    lookup_span({trace_id, span_id})
  end

  def lookup_span({trace_id, span_id} = key) when is_binary(trace_id) and is_binary(span_id) do
    current_time = System.monotonic_time(:millisecond)

    case :ets.lookup(@table_name, key) do
      [{{^trace_id, ^span_id}, expires_at, %Span{} = span}] when expires_at > current_time ->
        span

      [{{^trace_id, ^span_id}, _, %Span{} = span}] ->
        clear_span(span)
        nil

      _ ->
        nil
    end
  end

  defp ttl(), do: Application.get_env(:honeylixir_tracing, :span_ttl_sec, 300) * 1000
end
