defmodule HoneylixirTracing.Propogation do
  @moduledoc """
  Module responsible for enabling trace propogation.

  Propogation can be used to pass trace information between Processes within the
  same application or serialized to be sent to other services for distributed tracing.
  """

  defstruct [:dataset, :trace_id, :parent_id, :context]

  @typedoc """
  Struct used to pass propogation around between Elixir processes. Can also be
  serialized with `Kernel.to_string/1` as it implements `String.Chars` for use
  in headers.
  """
  @type t :: %__MODULE__{
          dataset: String.t(),
          trace_id: String.t(),
          parent_id: String.t(),
          context: nil
        }

  def to_string(%HoneylixirTracing.Propogation{
        dataset: dataset,
        trace_id: trace_id,
        parent_id: parent_id
      }) do
    encoded_dataset = URI.encode_www_form(dataset)

    "1;dataset=#{encoded_dataset},trace_id=#{trace_id},parent_id=#{parent_id},context="
  end

  @doc false
  def from_span(%HoneylixirTracing.Span{event: event, trace_id: trace_id, span_id: span_id}) do
    %HoneylixirTracing.Propogation{dataset: event.dataset, trace_id: trace_id, parent_id: span_id}
  end

  def from_span(_), do: nil

  defimpl String.Chars do
    def to_string(%HoneylixirTracing.Propogation{} = prop) do
      HoneylixirTracing.Propogation.to_string(prop)
    end
  end
end
