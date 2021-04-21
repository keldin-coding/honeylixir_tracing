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
      span("TestModule.cool_work/2", %{"arg1" => arg1, "arg2" => arg2}, fn ->
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
      span("TestModule.cool_work/2", %{"arg1" => arg1, "arg2" => arg2}, fn ->
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

  ### Adding data

  If you want to add fields to your spans after initialization or invocation, we can
  use `add_field_data/1` to add data. `add_field_data/1` accepts a Map of strings
  to any encodable entity (just like `span/2` and the underlying `Honeylixir.Event`)
  and modifies the currently active span with the information. If no span is active,
  this function does nothing.

  ```
  defmodule TestModule do
    def some_work() do
      span("TestModule.some_work/0", fn ->
        result = CoolModule.do_something_else()

        HoneylixirTracing.add_field_data(%{"cool_mod.result" => result})
      end)
    end
  end
  ```
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
      latest_span = HoneylixirTracing.Context.clear_current_span()

      # Account for something going wrong and the current span being missing
      # somehow. We'll assume horrible things happened and not try to send a
      # possibly broken and outdated span from above.
      if latest_span do
        latest_span
        |> Span.prepare_to_send()
        |> Event.send()
      end
    end
  end

  @doc """
  Adds field data to the current span.

  This function does nothing if there is no currently active span. Any duplicate field
  names will have their contents replaced. Returns an `:ok` if a span was updated
  successfully, `nil` if there is no span.
  """
  @spec add_field_data(Honeylixir.Event.fields_map()) :: :ok | nil
  def add_field_data(fields) when is_map(fields) do
    if current_span = HoneylixirTracing.Context.current_span() do
      HoneylixirTracing.Span.add_field_data(current_span, fields)
      |> HoneylixirTracing.Context.set_current_span()
    end
  end
end
