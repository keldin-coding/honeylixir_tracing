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

  describe "add_field_data/1" do
    test "adds to the underlying event the entire map given" do
      HoneylixirTracing.span("test span", fn ->
        assert :ok = HoneylixirTracing.add_field_data(%{"new field" => 1, "other" => 2})
      end)

      assert [%{"name" => "test span", "new field" => 1, "other" => 2}] =
               fieldsets_from_listener()
    end

    test "updates the span in ETS with the new data" do
      HoneylixirTracing.span("test span", %{"old field" => :old}, fn ->
        assert :ok = HoneylixirTracing.add_field_data(%{"new field" => 1})

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

  defp teardown() do
    Process.delete(:honeylixir_context)
    :ets.delete_all_objects(:honeylixir_tracing_context)
  end

  defp fieldsets_from_listener() do
    Enum.map(HoneylixirTestListener.values(), & &1.fields)
  end
end
