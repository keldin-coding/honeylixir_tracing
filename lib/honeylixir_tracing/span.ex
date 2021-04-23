defmodule HoneylixirTracing.Span do
  @moduledoc false

  alias Honeylixir.Event
  alias __MODULE__

  @trace_id_field "trace.trace_id"
  @span_id_field "trace.span_id"
  @parent_id_field "trace.parent_id"
  @duration_ms_field "duration_ms"

  @typedoc """
  Representation of a Span used internally.
  """
  @type t :: %__MODULE__{
          event: Honeylixir.Event.t(),
          parent_id: String.t(),
          span_id: String.t(),
          trace_id: String.t(),
          start_time: integer(),
          # May be unnecessary? dunno. Gets weird.
          sent: boolean()
        }

  defstruct [
    :event,
    :parent_id,
    :span_id,
    :trace_id,
    :start_time,
    sent: false
  ]

  @spec setup(String.t(), Honeylixir.Event.fields_map()) :: t()
  def setup(name, %{} = fields) when is_binary(name) do
    event = Honeylixir.Event.create(Map.put(fields, "name", name))
    start_time = System.monotonic_time()

    %Span{
      event: event,
      span_id: Honeylixir.generate_short_id(),
      parent_id: HoneylixirTracing.Context.current_span_id(),
      trace_id: HoneylixirTracing.Context.current_trace_id() || Honeylixir.generate_long_id(),
      start_time: start_time
    }
  end

  @spec setup(HoneylixirTracing.Propagation.t(), String.t(), Honeylixir.Event.fields_map()) :: t()
  def setup(
        %HoneylixirTracing.Propagation{
          trace_id: trace_id,
          parent_id: parent_id,
          dataset: dataset
        },
        name,
        %{} = fields
      )
      when is_binary(name) do
    event = Honeylixir.Event.create(Map.put(fields, "name", name))
    event = %{event | dataset: dataset}

    start_time = System.monotonic_time()

    %Span{
      event: event,
      span_id: Honeylixir.generate_short_id(),
      parent_id: parent_id,
      trace_id: trace_id,
      start_time: start_time
    }
  end

  @spec prepare_to_send(t()) :: Honeylixir.Event.t()
  def prepare_to_send(%Span{} = span) do
    span.event
    |> Event.add(%{
      @trace_id_field => span.trace_id,
      @span_id_field => span.span_id,
      @parent_id_field => span.parent_id,
      @duration_ms_field => duration_ms_from_nativetime(span.start_time, System.monotonic_time())
    })
  end

  def add_field_data(%Span{event: event} = span, fields) when is_map(fields) do
    %{span | event: Event.add(event, fields)}
  end

  defp duration_ms_from_nativetime(start_time, end_time) do
    diff = (end_time - start_time) |> System.convert_time_unit(:native, :microsecond)

    Float.round(diff / 1000, 3)
  end
end
