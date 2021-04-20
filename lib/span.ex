defmodule HoneylixirTracing.Span do
  alias Honeylixir.Event
  alias __MODULE__

  @trace_id_field "trace.trace_id"
  @span_id_field "trace.span_id"
  @parent_id_field "trace.parent_id"

  @type t :: %__MODULE__{
          event: Honeylixir.Event.t(),
          parent_id: String.t(),
          span_id: String.t(),
          trace_id: String.t(),
          # May be unnecessary? dunno. Gets weird.
          sent: boolean()
        }

  defstruct [
    :event,
    :parent_id,
    :span_id,
    :trace_id,
    sent: false
  ]

  def setup(name, %{} = fields) do
    event = Honeylixir.Event.create(Map.put(fields, "name", name))

    %Span{
      event: event,
      span_id: Honeylixir.generate_short_id(),
      parent_id: HoneylixirTracing.Context.current_parent_span_id(),
      trace_id: HoneylixirTracing.Context.current_trace_id()
    }
  end

  @spec prepare_to_send(t()) :: Honeylixir.Event.t()
  def prepare_to_send(%Span{} = span) do
    e =
      Event.add(
        span.event,
        %{
          @trace_id_field => span.trace_id,
          @span_id_field => span.span_id
        }
      )

    if span.parent_id do
      Event.add_field(e, @parent_id_field, span.parent_id)
    else
      Event.add_field(e, @parent_id_field, nil)
    end
  end
end
