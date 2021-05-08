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

  All of the required configuration for this package depends on configuration set for
  the `Honeylixir` project, the underlying library used for sending the data. The
  absolute minimum configuration required is to set the `team_writekey` and `dataset`
  fields:

  ```
  config :honeylixir,
    dataset: "your-dataset-name",
    team_writekey: "your-writekey"
  ```

  In addition, optional fields available for this package are as follows:

  |Name|Type|Description|Default|
  |---|---|---|---|
  |`:span_ttl_sec`|`integer`|How long an inactive span should remain in the ets table, in seconds, in case something has gone wrong|`300`|
  |`:reaper_interval_sec`|`integer`|How frequently the `HoneylixirTracing.Reaper` should run to cleanup the ets table of orphaned spans|`60`|

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

  If you wanted to trace this function, you could do:

  ```
  defmodule TestModule do
    def cool_work(arg1, arg2) do
      span("TestModule.cool_work/2", %{"arg1" => arg1, "arg2" => arg2}, fn ->
        arg1 + arg2
      end)
    end
  end
  ```

  Another option is to wrap the business work in a private function and invoke that
  in the span function:

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

  In both cases, the return value remains the same. The result of any `span` (`span/2`, `span/3`, `span/4`) calls
  is the result of whatever function is passed in as the work.

  ### Cross-Process traces

  Given this is Elixir running on Erlang, it's quite possible a GenServer or some other
  Process-based design will appear in your system. If this is the case, there are a couple of
  rough recommendations on how to ensure predictable tracing data:

  * For synchronous work, add a final argument of `ctx`, which is a `t:HoneylixirTracing.Propagation.t/0`
    struct, to the callback. This should not be *accepted* by the Client API but instead
    built for the user directly and passed to the Server. In the callback, use that as the
    first argument to a `HoneylixirTracing.span/4` call which wraps your work.
  * For asynchronous work, do *not* start a span from a context passed in.
    Asynchronous work is akin to background work done by a web application, meaning that
    one would consider them linked spans rather than child spans. You can use the
    underlying `Honeylixir` library to send these events along. Utility functions
    may be provided in the future to help with this.

  A small example for doing this within an application for synchronous work can be
  found in the `cross_process_example` project in the `examples` directory.

  ### Adding data to the current span

  If you want to add fields to your spans after initialization or invocation, you can
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

  ## The Reaper

  The `Reaper` module handles cleaning up the ets table used to store state. Two pieces
  of configuration relate to this:

  * `span_ttl_sec` -> how long a span should remain in the ets table
  * `:reaper_interval_sec` -> how frequently the Reaper should run in seconds

  If the Span TTL is set too low, it may cleanup active spans. The default is currently
  set to 5 minutes. However, if a span starts and runs for longer than 5 minutes, it
  will be deleted from the ets table. This does not inherently mean your span cannot
  be sent still. If it is still the *currently* active span and does not require a
  parent, then it will send fine. However, if your span does have a parent older than
  5 minutes, it's entirely probable you will end up with an incomplete trace.
  """
  @moduledoc since: "0.3.0"

  alias HoneylixirTracing.Span

  @typedoc """
  Create and send a span to Honeycomb.
  """
  @type span_return :: any()

  @typedoc """
  A 0 arity function used as the work to be measured by the span.
  """
  @type work_function :: (() -> any())

  @doc """
  Create and send a span to Honeycomb.
  """
  @doc since: "0.2.0"
  @spec span(String.t(), work_function()) :: span_return()
  def span(span_name, work) when is_binary(span_name) and is_function(work, 0),
    do: span(span_name, %{}, work)

  @doc """
  Create and send a span to Honeycomb by propogating tracing context.

  Accepts a `t:HoneylixirTracing.Propagation.t/0` for continuing work from another Process's trace.
  """
  @doc since: "0.2.0"
  @spec span(
          HoneylixirTracing.Propagation.t(),
          String.t(),
          Honeylixir.Event.fields_map(),
          work_function()
        ) :: span_return()
  def span(%HoneylixirTracing.Propagation{} = propagation, span_name, %{} = fields, work)
      when is_binary(span_name) and is_function(work, 0) do
    Span.setup(propagation, span_name, fields)
    |> do_span(work)
  end

  @doc """
  Create and send a span to Honeycomb by optionally propogating tracing context.

  This form, `span/3`, has two possible calling signatures: the first is a non-propogated
  span with initial fields; the second accepts a propogated trace but no initial fields.
  """
  @doc since: "0.2.0"
  @spec span(HoneylixirTracing.Propagation.t(), String.t(), work_function()) :: span_return()
  @spec span(String.t(), Honeylixir.Event.fields_map(), work_function()) :: span_return()
  def span(propagation_or_name, name_or_fields, work)

  def span(span_name, %{} = fields, work) when is_binary(span_name) and is_function(work, 0) do
    Span.setup(span_name, fields) |> do_span(work)
  end

  def span(%HoneylixirTracing.Propagation{} = prop, span_name, work)
      when is_binary(span_name) and is_function(work, 0) do
    Span.setup(prop, span_name, %{})
    |> do_span(work)
  end

  defp do_span(%HoneylixirTracing.Span{} = span, work) do
    {:ok, previous_span} = HoneylixirTracing.Context.set_current_span(span)

    try do
      work.()
      # rescue
      #   err when is_exception(err) ->
      #     HoneylixirTracing.add_field_data(%{"error_type" => err.__struct__, "error" => err.message})
    after
      # Account for something going wrong and the current span being missing
      # somehow. We'll assume horrible things happened and not try to send a
      # possibly broken and outdated span from above.
      end_span(previous_span)
    end
  end

  @doc """
  Start a span and manage ending it yourself.

  See `start_span/3`.
  """
  @doc since: "0.3.0"
  @spec start_span(HoneylixirTracing.Propagation.t(), String.t()) ::
          {:ok, HoneylixirTracing.Span.t() | nil}
  @spec start_span(String.t(), Honeylixir.Event.fields_map()) ::
          {:ok, HoneylixirTracing.Span.t() | nil}
  def start_span(propagation_or_name, name_or_fields)

  def start_span(%HoneylixirTracing.Propagation{} = propagation, name) when is_binary(name) do
    start_span(propagation, name, %{})
  end

  def start_span(name, fields) when is_binary(name) and is_map(fields) do
    Span.setup(name, fields)
    |> HoneylixirTracing.Context.set_current_span()
  end

  @doc """
  Start a span and manage ending it yourself.

  Functionally looks and behaves much like the `span` functions. It accepts some combination of
  a propagation context, a span name, and a set of fields to start a span. The result
  is a tuple of `:ok` and whatever the previous current span was. You can use this
  in an `end_span/1` call to set the current span back to what it used to be.

  Every usage of `start_span` MUST have an `end_span` call or you may end up with
  unfinished spans or traces or other unexpected and undesirable results, such as
  a current span that lives longer than it should. If you can, try to store the
  previous span somewhere you can use to reset the current span. It is
  recommended you only use this in cases where this is impossible since in those
  places you could probably use a function in the `span` family instead. A common
  example for using this is using `:telemetry` events as spans when those events
  only give a duration rather than at least a start time.
  """
  @doc since: "0.3.0"
  @spec start_span(HoneylixirTracing.Propagation.t(), String.t(), Honeylixir.Event.fields_map()) ::
          {:ok, HoneylixirTracing.Span.t() | nil}
  def start_span(%HoneylixirTracing.Propagation{} = propagation, name, fields)
      when is_binary(name) and is_map(fields) do
    Span.setup(propagation, name, fields)
    |> HoneylixirTracing.Context.set_current_span()
  end

  @doc """
  Used for manually ending the currently active span.

  This SHOULD only be used with `start_span` calls. Any `end_span` call SHOULD have
  a corresponding `start_span` call, though it will not result in an error if there is
  no active span. The optional `previous_span` argument is what the currently active
  span will be set to after the current one is sent.
  """
  @doc since: "0.3.0"
  def end_span(previous_span \\ nil) do
    if current_span = HoneylixirTracing.Context.current_span() do
      Span.send(current_span)
      HoneylixirTracing.Context.clear_span(current_span)
    end

    HoneylixirTracing.Context.set_current_span(previous_span)
  end

  @doc """
  Adds field data to the current span.

  This function does nothing if there is no currently active span. Any duplicate field
  names will have their contents replaced. Returns the updated span if one is active,
  `nil` otherwise.
  """
  @doc since: "0.3.0"
  @spec add_field_data(Honeylixir.Event.fields_map()) :: Honeylixir.Span.t() | nil
  def add_field_data(fields) when is_map(fields) do
    if current_span = HoneylixirTracing.Context.current_span() do
      new_span = HoneylixirTracing.Span.add_field_data(current_span, fields)

      HoneylixirTracing.Context.set_current_span(new_span)

      new_span
    end
  end

  @doc """
  Provides a `t:Honeylixir.Propagation.t/0` for sharing tracing data between processes.

  If there is no span currently active, this will return `nil`.
  """
  @doc since: "0.2.0"
  @spec current_propagation_context() :: HoneylixirTracing.Propagation.t() | nil
  def current_propagation_context() do
    HoneylixirTracing.Context.current_span()
    |> HoneylixirTracing.Propagation.from_span()
  end

  @doc """
  Helper method for sending a `link` span annotation.

  Accepts a `t:Honeylixir.Propagation.t/0` as the data for what span to link to.
  If no span is currently active, does nothing and returns `nil`. Please consider
  this feature experimental.
  """
  @doc since: "0.3.0"
  def link_to_span(%HoneylixirTracing.Propagation{parent_id: span_id, trace_id: trace_id}) do
    if current_span = HoneylixirTracing.Context.current_span() do
      event =
        Honeylixir.Event.create(%{
          "trace.link.trace_id" => trace_id,
          "trace.link.span_id" => span_id,
          "meta.span_type" => "link",
          "trace.parent_id" => current_span.span_id,
          "trace.trace_id" => current_span.trace_id
        })

      %{event | sample_rate: 1} |> Honeylixir.Event.send()
    end
  end

  def link_to_span(_), do: nil
end
