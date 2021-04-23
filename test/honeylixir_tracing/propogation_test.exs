defmodule HoneylixirTracing.PropogationTest do
  use ExUnit.Case
  alias HoneylixirTracing.Propogation

  setup do
    %{span: HoneylixirTracing.Span.setup("span", %{})}
  end

  describe "to_string/1" do
    test "ensures the dataset name is URL encoded", %{span: span} do
      event = span.event
      event = %{event | dataset: "with a space"}
      span = %{span | event: event}

      propogation =
        span
        |> Propogation.from_span()
        |> Propogation.to_string()

      assert String.contains?(propogation, "dataset=with+a+space")
    end

    test "generates a header string in Honeycomb format", %{span: span} do
      propogation =
        span
        |> Propogation.from_span()
        |> Propogation.to_string()

      assert propogation ==
               "1;dataset=honeylixir-test,trace_id=#{span.trace_id},parent_id=#{span.span_id},context="
    end
  end
end
