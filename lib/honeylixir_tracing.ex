defmodule HoneylixirTracing do
  @moduledoc """
  Used to trace units of work and send the information to Honeycomb.

  ## Installation

  Adding the library to your mix.exs as a dependency should suffice:

  ```
  def deps() do
    [
      {:honeylixir_tracing, "~> 0.2.0"}
    ]
  end
  ```

  This is the main entrypoint for this package, used to trace units of work by
  wrapping them in a function and report the duration as well as its relation
  to parent work.

  ## Configuration

  Most of the configuration for this package depends on configuration set for
  the `Honeylixir` project, the underlying library used for sending the data. The
  absolute minimum configuration required is to set the `team_writekey` and `dataset`
  fields:

  ```
  config :honeylixir,
    dataset: "your-dataset-name",
    team_writekey: "your-writekey"
  ```

  ## Usage

  Basic usage is to wrap any unit of work in a `HoneylixirTracing.span` call. Let's
  say you had the following module in your application already:

  ```
  defmodule TestModule do
    def cool_work(arg1, arg2) do
      arg1 + arg2
    end
  end
  ```

  If we wanted to trace this function, we could do this:

  ```
  defmodule TestModule do
    def cool_work(arg1, arg2) do
      span("doing-cool-work", %{"arg1" => arg1, "arg2" => arg2}, fn ->
        arg1 + arg2
      end)
    end
  end
  ```

  Another option, if we didn't want to increase the nesting of our business logic,
  would be to extract the logic into a private function:

  ```
  defmodule TestModule do
    def cool_work(arg1, arg2) do
      span("doing-cool-work", %{"arg1" => arg1, "arg2" => arg2}, fn ->
        do_cool_work(arg1, arg2)
      end)
    end

    defp do_cool_work(arg1, arg) do
      arg1 + arg2
    end
  end
  ```

  In both cases, the return value remains the same. The result of `span/2,3` calls
  is the result of whatever function is passed in as the work.
  """

  alias Honeylixir.Event
  alias HoneylixirTracing.Span

  @typedoc """
  Span returns whatever the result of the work function given is.
  """
  @type span_return() :: any()

  @doc """
  Send a span to Honeycomb of the given name.

  See `span/3` for full details. This version uses an empty map for the `fields`
  argument.
  """
  @spec span(String.t(), (() -> any())) :: span_return()
  def span(span_name, work) when is_binary(span_name) and is_function(work, 0),
    do: span(span_name, %{}, work)

  @doc """
  Send a span to Honeycomb of the given name with the specified fields attached.
  """
  @spec span(String.t(), Honeylixir.Event.fields_map(), (() -> any())) :: span_return()
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
