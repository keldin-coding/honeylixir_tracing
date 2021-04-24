defmodule HoneylixirTracing.PropagationTest do
  use ExUnit.Case
  alias HoneylixirTracing.Propagation

  setup do
    %{span: HoneylixirTracing.Span.setup("span", %{})}
  end

  describe "to_string/1" do
    test "ensures the dataset name is URL encoded", %{span: span} do
      event = span.event
      event = %{event | dataset: "with a space"}
      span = %{span | event: event}

      propagation =
        span
        |> Propagation.from_span()
        |> to_string()

      assert String.contains?(propagation, "dataset=with+a+space")
    end

    test "generates a header string in Honeycomb format", %{span: span} do
      propagation =
        span
        |> Propagation.from_span()
        |> to_string()

      assert propagation ==
               "1;dataset=honeylixir-test,trace_id=#{span.trace_id},parent_id=#{span.span_id},context="
    end
  end

  describe "parse_header/1" do
    test "returns nil for non-string" do
      assert is_nil(Propagation.parse_header(1))
    end

    test "returns nil for non-regex matching header" do
      assert is_nil(Propagation.parse_header("1;dataset=nice&cool,whatever"))
    end

    test "returns the propagation context", %{span: span} do
      propagation = Propagation.from_span(span)

      assert ^propagation = Propagation.parse_header(to_string(propagation))
    end
  end
end
