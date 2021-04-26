defmodule HoneylixirTracing.Propagation do
  @moduledoc """
  Module responsible for enabling trace propagation.

  Propagation can be used to pass trace information between Processes within the
  same application or serialized to be sent to other services for distributed tracing.
  """

  defstruct [:dataset, :trace_id, :parent_id, :context]

  @typedoc """
  Struct used to pass propagation around between Elixir processes.

  Can also be serialized with `Kernel.to_string/1` as it implements `String.Chars`
  for use in headers.
  """
  @type t :: %__MODULE__{
          dataset: String.t(),
          trace_id: String.t(),
          parent_id: String.t(),
          context: nil
        }
  # Yeah. It sucks. C'est la vie. There's probably a pattern matching on binaries
  # lurking in here, but I don't know it or see it.
  @header_parse_regex ~r/1;dataset=(?<dataset>[^,]+),trace_id=(?<trace_id>[[:xdigit:]]+),parent_id=(?<parent_id>[[:xdigit:]]+)/
  @header_key "X-Honeycomb-Trace"

  @doc """
  Provides map of the header key to the propogation context as a string.

  Sets the Header key to `"X-Honeycomb-Trace"` in the map. Note that context is
  given as an empty string for now as trace fields are not supported.
  """
  @spec header(t()) :: %{String.t() => String.t()}
  def header(%HoneylixirTracing.Propagation{} = prop),
    do: %{@header_key => to_string(prop)}

  @doc """
  Parses out the Honeycomb trace header string.

  Note that the context is ignored as trace fields are not currently supported. If
  the parsing fails, `nil` is returned.
  """
  @spec parse_header(String.t()) :: t() | nil
  def parse_header(header) when is_binary(header) do
    case Regex.named_captures(@header_parse_regex, header) do
      %{"dataset" => dataset, "trace_id" => trace_id, "parent_id" => parent_id} ->
        %HoneylixirTracing.Propagation{dataset: dataset, trace_id: trace_id, parent_id: parent_id}

      _ ->
        nil
    end
  end

  def parse_header(_), do: nil

  @doc false
  def from_span(%HoneylixirTracing.Span{event: event, trace_id: trace_id, span_id: span_id}) do
    %HoneylixirTracing.Propagation{dataset: event.dataset, trace_id: trace_id, parent_id: span_id}
  end

  def from_span(_), do: nil

  defimpl String.Chars do
    def to_string(%HoneylixirTracing.Propagation{
          dataset: dataset,
          trace_id: trace_id,
          parent_id: parent_id
        }) do
      encoded_dataset = URI.encode_www_form(dataset)

      "1;dataset=#{encoded_dataset},trace_id=#{trace_id},parent_id=#{parent_id},context="
    end
  end
end
