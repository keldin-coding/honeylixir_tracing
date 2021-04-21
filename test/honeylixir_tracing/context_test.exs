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

    test "returns the span at the head of the list" do
      Process.put(:honeylixir_context, [
        Span.setup("newest", %{}),
        Span.setup("oldest", %{})
      ])

      assert Context.current_span().event.fields["name"] == "newest"

      teardown()
    end
  end

  describe "set_current_span/1 for span" do
    test "allows setting first span" do
      span = Span.setup("cool_times", %{})

      assert :ok = Context.set_current_span(span)

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

      assert :ok = Context.set_current_span({span.trace_id, span.span_id})
      assert Context.current_span() == span

      teardown()
    end

    test "returns nil if the span defined by that {trace_id, span_id} combo is unknown" do
      teardown()

      assert is_nil(Context.set_current_span({"no", "no"}))

      teardown()
    end
  end

  describe "current_span_id/0" do
    test "returns the span_id of the current span" do
      assert is_nil(Context.current_span_id())

      span = Span.setup("foo", %{})
      :ok = Context.set_current_span(span)

      refute is_nil(Context.current_span_id())
      assert Context.current_span_id() == span.span_id

      teardown()
    end
  end

  describe "current_trace_id/0" do
    test "returns the trace_id of the current span" do
      assert is_nil(Context.current_trace_id())

      span = Span.setup("foo", %{})
      :ok = Context.set_current_span(span)

      refute is_nil(Context.current_trace_id())
      assert Context.current_trace_id() == span.trace_id

      teardown()
    end
  end

  describe "the current span stack" do
    test "allows setting multiple current spans, building a stack of them" do
      parent_span = Span.setup("parent", %{"branch" => 0})
      child_span = Span.setup("child", %{"branch" => 1})
      grandchild_span = Span.setup("grandchild", %{"branch" => 2})

      assert :ok = Context.set_current_span(parent_span)
      assert :ok = Context.set_current_span(child_span)
      assert :ok = Context.set_current_span(grandchild_span)

      assert Context.current_span() == grandchild_span
      Context.clear_current_span()

      assert Context.current_span() == child_span
      Context.clear_current_span()

      assert Context.current_span() == parent_span
      Context.clear_current_span()

      assert is_nil(Context.current_span())

      teardown()
    end
  end

  defp teardown() do
    Process.delete(:honeylixir_context)
    :ets.delete_all_objects(:honeylixir_tracing_context)
  end
end
