defmodule HoneylixirTracingTest do
  use ExUnit.Case
  doctest HoneylixirTracing

  setup do
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

  defp fieldsets_from_listener() do
    Enum.map(HoneylixirTestListener.values(), & &1.fields)
  end
end
