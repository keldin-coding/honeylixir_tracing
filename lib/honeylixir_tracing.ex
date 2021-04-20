defmodule HoneylixirTracing do
  @moduledoc """
  Documentation for `HoneylixirTracing`.
  """

  alias Honeylixir.Event
  alias HoneylixirTracing.Span

  def span(span_name, work) when is_binary(span_name) and is_function(work, 0),
    do: span(span_name, %{}, work)

  # This whole function is...weird. We gotta find a better way to do a lot of this.
  def span(span_name, %{} = fields, work) when is_binary(span_name) and is_function(work, 0) do
    # This can all probably be pushed to Span
    span = Span.setup(span_name, fields)

    # Context management is STRANGE, maybe let's not do that here like this?
    HoneylixirTracing.Context.add_span(span)

    previous_context = HoneylixirTracing.Context.current()
    new_context = HoneylixirTracing.Context.from_span(span)

    Process.put(:current_context, new_context)

    start_time = System.monotonic_time()

    try do
      work.()
    after
      duration_ms = duration_ms_from_natives(start_time, System.monotonic_time())

      Process.put(:current_context, previous_context)
      # Once we're nesting, this has to become trace aware but for now this is FineTM
      span
      |> Span.prepare_to_send()
      |> Event.add_field("duration_ms", duration_ms)
      |> Event.send()
    end
  end

  defp duration_ms_from_natives(start_time, end_time) do
    diff = (end_time - start_time) |> System.convert_time_unit(:native, :microsecond)

    Float.round(diff / 1000, 3)
  end
end
