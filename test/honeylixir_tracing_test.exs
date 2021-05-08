defmodule HoneylixirTracingTest do
  use ExUnit.Case
  doctest HoneylixirTracing

  setup do
    teardown()
    start_supervised!(HoneylixirTestListener)

    :ok
  end

  describe "span/2" do
    test "returns the result of the function given" do
      func = fn -> :my_cool_atom end

      assert HoneylixirTracing.span("test", func) == :my_cool_atom
    end

    test "allows nesting spans" do
      HoneylixirTracing.span("parent", fn ->
        HoneylixirTracing.span("child", fn -> :child_result end)

        HoneylixirTracing.span("second child", fn ->
          HoneylixirTracing.span("grandchild", fn -> :grandchild end)

          :second_child
        end)

        :parent_result
      end)

      # This list is in reverse order from how they were sent.
      assert [
               %{"name" => "parent"},
               %{"name" => "second child"},
               %{"name" => "grandchild"},
               %{"name" => "child"}
             ] = fieldsets_from_listener()
    end

    test "still sends the span if an error is raised" do
      assert_raise RuntimeError, fn ->
        HoneylixirTracing.span("parent", fn ->
          HoneylixirTracing.span("errored_child", fn -> raise "Bad dog" end)
        end)
      end

      assert [
               %{"name" => "parent"},
               %{"name" => "errored_child"}
             ] = fieldsets_from_listener()
    end
  end

  describe "span/3" do
    test "returns the result of the function given" do
      func = fn -> :my_cool_atom end

      assert HoneylixirTracing.span("test", %{"nice" => "nice"}, func) == :my_cool_atom
    end

    test "allows nesting spans" do
      HoneylixirTracing.span("parent", %{"a" => 1}, fn ->
        HoneylixirTracing.span("child", %{"b" => 2}, fn -> :child_result end)

        HoneylixirTracing.span("second child", %{"c" => 3}, fn ->
          HoneylixirTracing.span("grandchild", %{"d" => 4}, fn -> :grandchild end)

          :second_child
        end)

        :parent_result
      end)

      # This list is in reverse order from how they were sent.
      assert [
               %{"name" => "parent", "a" => 1},
               %{"name" => "second child", "c" => 3},
               %{"name" => "grandchild", "d" => 4},
               %{"name" => "child", "b" => 2}
             ] = fieldsets_from_listener()
    end

    test "still sends the span if an error is raised" do
      assert_raise RuntimeError, fn ->
        HoneylixirTracing.span("parent", %{"a" => 1}, fn ->
          HoneylixirTracing.span("errored_child", %{"b" => 2}, fn -> raise "Bad dog" end)
        end)
      end

      assert [
               %{"name" => "parent", "a" => 1},
               %{"name" => "errored_child", "b" => 2}
             ] = fieldsets_from_listener()
    end
  end

  describe "span/3 with propagation" do
    test "sets the shared tracing data appropriately" do
      parent_span = HoneylixirTracing.Span.setup("parent", %{})
      event = %{parent_span.event | dataset: "something-fake"}
      parent_span = %{parent_span | event: event}

      {:ok, _} = HoneylixirTracing.Context.set_current_span(parent_span)
      propagation = HoneylixirTracing.current_propagation_context()

      # This is dumb, but it ensures there is no current span
      teardown()

      assert is_nil(HoneylixirTracing.Context.current_span())

      assert :ok = HoneylixirTracing.span(propagation, "test child", fn -> :ok end)

      [sent_span] = fieldsets_from_listener()

      assert Map.get(sent_span, "trace.trace_id") == parent_span.trace_id
      assert Map.get(sent_span, "trace.parent_id") == parent_span.span_id
      assert Map.get(sent_span, "name") == "test child"
    end
  end

  describe "span/4 with propagation" do
    test "sets the shared tracing data appropriately" do
      parent_span = HoneylixirTracing.Span.setup("parent", %{})
      event = %{parent_span.event | dataset: "something-fake"}
      parent_span = %{parent_span | event: event}

      {:ok, _} = HoneylixirTracing.Context.set_current_span(parent_span)
      propagation = HoneylixirTracing.current_propagation_context()

      # This is dumb, but it ensures there is no current span
      teardown()

      assert is_nil(HoneylixirTracing.Context.current_span())

      assert :ok =
               HoneylixirTracing.span(propagation, "test child", %{"cool" => "people"}, fn ->
                 :ok
               end)

      [sent_span] = fieldsets_from_listener()

      assert Map.get(sent_span, "trace.trace_id") == parent_span.trace_id
      assert Map.get(sent_span, "trace.parent_id") == parent_span.span_id
      assert Map.get(sent_span, "name") == "test child"
      assert Map.get(sent_span, "cool") == "people"
    end
  end

  describe "add_field_data/1" do
    test "adds to the underlying event the entire map given" do
      HoneylixirTracing.span("test span", fn ->
        assert span = HoneylixirTracing.add_field_data(%{"new field" => 1, "other" => 2})
        refute is_nil(span)

        assert span.event.fields["new field"] == 1
        assert span.event.fields["other"] == 2
      end)

      assert [%{"name" => "test span", "new field" => 1, "other" => 2}] =
               fieldsets_from_listener()
    end

    test "updates the span in ETS with the new data" do
      HoneylixirTracing.span("test span", %{"old field" => :old}, fn ->
        HoneylixirTracing.add_field_data(%{"new field" => 1})

        # This is convoluted, but here we go... We're going to get the current
        # span which is in the process dictionary. Then use the {trace_id, span_id}
        # tuple from it which serves as the key in our :ets table. Then manually
        # do a lookup in the table and ensure it has our new field set.
        assert span = HoneylixirTracing.Context.current_span()

        %HoneylixirTracing.Span{trace_id: trace_id, span_id: span_id} = span

        assert [{{^trace_id, ^span_id}, _ttl, found_span}] =
                 :ets.lookup(:honeylixir_tracing_context, {span.trace_id, span.span_id})

        assert found_span.event.fields["new field"] == 1
        assert found_span.event.fields["old field"] == :old
      end)
    end

    test "does nothing if there is no current span" do
      assert is_nil(HoneylixirTracing.add_field_data(%{"new field" => 1}))
    end
  end

  describe "current_propagation_context/0" do
    test "returns nil if there is no current span" do
      assert is_nil(HoneylixirTracing.current_propagation_context())
    end

    test "returns a propagation context when a current span exists" do
      span = HoneylixirTracing.Span.setup("foo", %{})
      {:ok, _} = HoneylixirTracing.Context.set_current_span(span)

      %HoneylixirTracing.Span{
        trace_id: expected_trace_id,
        span_id: expected_parent_id,
        event: event
      } = span

      expected_dataset = event.dataset

      assert %HoneylixirTracing.Propagation{
               trace_id: ^expected_trace_id,
               parent_id: ^expected_parent_id,
               dataset: ^expected_dataset,
               context: nil
             } = HoneylixirTracing.current_propagation_context()

      teardown()
    end
  end

  describe "link_to_span/1" do
    test "does nothing with no active span" do
      prop = %HoneylixirTracing.Propagation{trace_id: "foo", parent_id: "bar"}

      assert is_nil(HoneylixirTracing.link_to_span(prop))

      assert [] = HoneylixirTestListener.values()
    end

    test "does nothing when given a non-propagation argument" do
      assert is_nil(HoneylixirTracing.link_to_span(nil))

      assert [] = HoneylixirTestListener.values()
    end

    test "sends a span annotation based on the propagation" do
      prop = %HoneylixirTracing.Propagation{trace_id: "foo", parent_id: "bar"}

      HoneylixirTracing.span("parent", fn ->
        HoneylixirTracing.link_to_span(prop)
      end)

      assert [span_event, annotation] = HoneylixirTestListener.values()

      span_event_span_id = span_event.fields["trace.span_id"]
      span_event_trace_id = span_event.fields["trace.trace_id"]

      assert %{
               "trace.link.trace_id" => "foo",
               "trace.link.span_id" => "bar",
               "meta.span_type" => "link",
               "trace.parent_id" => ^span_event_span_id,
               "trace.trace_id" => ^span_event_trace_id
             } = annotation.fields
    end
  end

  describe "manual span management" do
    test "accepts propagation as well" do
      prop =
        HoneylixirTracing.Span.setup("parent1", %{}) |> HoneylixirTracing.Propagation.from_span()

      HoneylixirTracing.start_span(prop, "child")
      HoneylixirTracing.end_span()

      [child_event] = HoneylixirTestListener.values()
      assert child_event.fields["trace.trace_id"] == prop.trace_id
      assert child_event.fields["trace.parent_id"] == prop.parent_id
      assert child_event.fields["name"] == "child"

      HoneylixirTestListener.clear()

      HoneylixirTracing.start_span(prop, "another_child", %{"cool" => "magoo"})
      HoneylixirTracing.end_span()

      [child_event] = HoneylixirTestListener.values()
      assert child_event.fields["trace.trace_id"] == prop.trace_id
      assert child_event.fields["trace.parent_id"] == prop.parent_id
      assert child_event.fields["name"] == "another_child"
      assert child_event.fields["cool"] == "magoo"
    end

    test "an extra end_span does nothing" do
      HoneylixirTracing.start_span("nice", %{})
      HoneylixirTracing.end_span()
      HoneylixirTracing.end_span()

      assert [%Honeylixir.Event{} = event] = HoneylixirTestListener.values()
      assert event.fields["name"] == "nice"
    end

    test "when no previous span is given to end_span, previous spans will be orphaned" do
      HoneylixirTracing.start_span("lost", %{})
      {:ok, lost_span} = HoneylixirTracing.start_span("nice", %{})

      HoneylixirTracing.end_span()
      assert is_nil(HoneylixirTracing.Context.current_span())

      HoneylixirTracing.end_span()
      assert is_nil(HoneylixirTracing.Context.current_span())

      sent_events = HoneylixirTestListener.values()
      assert length(sent_events) == 1

      assert [nice_event] = HoneylixirTestListener.values()
      assert nice_event.fields["name"] == "nice"

      assert is_nil(
               HoneylixirTracing.Context.lookup_span(
                 {nice_event.fields["trace.trace_id"], nice_event.fields["trace.span_id"]}
               )
             )

      assert HoneylixirTracing.Context.lookup_span(lost_span)
    end

    test "with previous span stored, we can go back in the stack" do
      {:ok, parent_previous} = HoneylixirTracing.start_span("parent", %{})
      {:ok, child_previous} = HoneylixirTracing.start_span("child", %{})

      HoneylixirTracing.end_span(child_previous)
      assert HoneylixirTracing.Context.current_span() == child_previous

      HoneylixirTracing.end_span(parent_previous)
      assert is_nil(HoneylixirTracing.Context.current_span())

      sent_events = HoneylixirTestListener.values()
      assert length(sent_events) == 2

      assert [parent_event, child_event] = HoneylixirTestListener.values()

      %{"trace.trace_id" => parent_trace_id, "trace.span_id" => parent_span_id} =
        parent_event.fields

      %{"trace.trace_id" => child_trace_id, "trace.span_id" => child_span_id} = child_event.fields

      assert is_nil(HoneylixirTracing.Context.lookup_span({parent_trace_id, parent_span_id}))
      assert is_nil(HoneylixirTracing.Context.lookup_span({child_trace_id, child_span_id}))
    end
  end

  defp teardown() do
    Process.delete(:honeylixir_context)
    :ets.delete_all_objects(:honeylixir_tracing_context)
  end

  defp fieldsets_from_listener() do
    Enum.map(HoneylixirTestListener.values(), & &1.fields)
  end
end
