defmodule HoneylixirTracing.ContextTest do
  use ExUnit.Case
  alias HoneylixirTracing.{Context, Span}
  doctest HoneylixirTracing.Context

  setup do
    teardown()

    :ok
  end

  describe "current_span/0" do
    test "returns nil for an empty context" do
      Process.delete(:honeylixir_context)

      assert is_nil(Context.current_span())

      teardown()
    end

    test "returns the span set as current" do
      start_supervised!(HoneylixirTestListener)

      HoneylixirTracing.span("older", fn ->
        HoneylixirTracing.span("newer", fn ->
          assert Context.current_span().event.fields["name"] == "newer"
        end)
      end)

      teardown()
    end
  end

  describe "set_current_span/1 for span" do
    test "allows setting first span" do
      span = Span.setup("cool_times", %{})

      assert {:ok, nil} = Context.set_current_span(span)

      assert Context.current_span() == span

      trace_id = span.trace_id
      span_id = span.span_id

      assert [{{^trace_id, ^span_id}, _ttl, ^span}] =
               :ets.lookup(:honeylixir_tracing_context, {span.trace_id, span.span_id})

      teardown()
    end
  end

  describe "set_current_span/1 for tuple" do
    test "returns :ok when the span is found in the ets table" do
      span = Span.setup("cool_times", %{})
      Context.set_current_span(span)

      # Artificially clear this from the process dictionary.
      Process.delete(:honeylixir_context)
      assert is_nil(Context.current_span())

      assert {:ok, nil} = Context.set_current_span({span.trace_id, span.span_id})
      assert Context.current_span() == span

      teardown()
    end

    test "returns nil if the span defined by that {trace_id, span_id} combo is unknown" do
      teardown()

      assert {:ok, nil} = Context.set_current_span({"no", "no"})

      teardown()
    end
  end

  describe "current_span_id/0" do
    test "returns the span_id of the current span" do
      assert is_nil(Context.current_span_id())

      span = Span.setup("foo", %{})
      {:ok, nil} = Context.set_current_span(span)

      refute is_nil(Context.current_span_id())
      assert Context.current_span_id() == span.span_id

      teardown()
    end
  end

  describe "current_trace_id/0" do
    test "returns the trace_id of the current span" do
      assert is_nil(Context.current_trace_id())

      span = Span.setup("foo", %{})
      {:ok, _} = Context.set_current_span(span)

      refute is_nil(Context.current_trace_id())
      assert Context.current_trace_id() == span.trace_id

      teardown()
    end
  end

  defp teardown() do
    Process.delete(:honeylixir_context)
    :ets.delete_all_objects(:honeylixir_tracing_context)
  end
end
