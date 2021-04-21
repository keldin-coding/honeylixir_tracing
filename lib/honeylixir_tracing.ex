defmodule HoneylixirTracing do
  @moduledoc """
  Documentation for `HoneylixirTracing`.
  """

  alias Honeylixir.Event
  alias HoneylixirTracing.Span

  @doc """
  Span returns whatever the result of the work function given is.
  """
  @type span_return() :: any()

  @spec span(String.t(), (() -> any())) :: span_return()
  def span(span_name, work) when is_binary(span_name) and is_function(work, 0),
    do: span(span_name, %{}, work)

  @spec span(String.t(), Honeylixir.fields_map(), (() -> any())) :: span_return()
  def span(span_name, %{} = fields, work) when is_binary(span_name) and is_function(work, 0) do
    span = Span.setup(span_name, fields)
    HoneylixirTracing.Context.set_current_span(span)

    try do
      work.()
    after
      HoneylixirTracing.Context.clear_current_span()

      span
      |> Span.prepare_to_send()
      |> Event.send()
    end
  end
end
