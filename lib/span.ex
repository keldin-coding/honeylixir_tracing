defmodule HoneylixirTracing.Context do
  defstruct [
    :current_span_id,
    :previous_span_id,
    :trace_id
  ]
end

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
    sent: boolean() # May be unnecessary? dunno. Gets weird.
  }

  defstruct [
    :event,
    :parent_id,
    :span_id,
    :trace_id,
    sent: false
  ]

  def setup(%Event{} = event) do
    %Span{
      event: event,
      span_id: Honeylixir.generate_short_id(),
      parent_id: current_parent_span(),
      trace_id: current_trace_id()
    }
  end

  @spec prepare_to_send(t()) :: Honeylixir.Event.t()
  def prepare_to_send(%Span{} = span) do
    e = Event.add(
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

  # Getting and creating these should probably be in context, but we roll with here for now
  defp current_parent_span do
    Process.get(:current_context, %HoneylixirTracing.Context{}).current_span_id
  end

  defp current_trace_id do
    ctx = Process.get(:current_context, %HoneylixirTracing.Context{})

    ctx.trace_id || Honeylixir.generate_long_id()
  end
end
