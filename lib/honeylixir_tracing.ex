defmodule HoneylixirTracing do
  @moduledoc """
  Documentation for `HoneylixirTracing`.
  """

  alias Honeylixir.Event
  alias HoneylixirTracing.Span

  def with_trace(span_name, fun) when is_binary(span_name) and is_function(fun, 0), do: with_trace(span_name, %{}, fun)

  def with_trace(span_name, %{} = fields, fun) when is_binary(span_name) and is_function(fun, 0) do
    span = Event.create(Map.put(fields, "name", span_name)) |> Span.setup()

    previous_context = Process.get(:current_context, %HoneylixirTracing.Context{})
    new_context = %HoneylixirTracing.Context{
      trace_id: span.trace_id,
      current_span_id: span.span_id,
      previous_span_id: previous_context.current_span_id
    }

    Process.put(:current_context, new_context)

    start = System.monotonic_time()
    # Passing the span down doesn't work because...immutable lol. Need a func
    # for adding fields to the event.
    result = fun.()
    end_time = System.monotonic_time()

    Process.put(:current_context, previous_context)
    # Once we're nesting, this has to become trace aware but for now this is FineTM
    span
      |> Span.prepare_to_send()
      |> Event.add_field("duration_ms", duration_ms_from_natives(start, end_time))
      |> Event.send()


    result
  end

  defp duration_ms_from_natives(start_time, end_time) do
    diff = (end_time - start_time) |> System.convert_time_unit(:native, :microsecond)

    Float.round(diff / 1000, 3)
  end
end
