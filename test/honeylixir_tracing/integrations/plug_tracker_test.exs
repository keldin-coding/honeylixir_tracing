defmodule HoneylixirTracing.Integrations.PlugTrackerTest do
  use ExUnit.Case

  alias HoneylixirTracing.Integrations.PlugTracker
  alias HoneylixirTracing.Context

  setup do
    start_supervised!(HoneylixirTestListener)
    :ok
  end

  describe "handle_info/2 monitored process down" do
    test "does nothing if the ref is unknown" do
      state = %{make_ref() => :none, make_ref() => :other}

      test_ref = make_ref()

      assert {:noreply, ^state} =
               PlugTracker.handle_info({:DOWN, test_ref, :process, nil, :normal}, state)

      assert [] = HoneylixirTestListener.values()
    end

    test "only removes the ref but sends nothing when no matching trace is found" do
      test_ref = make_ref()
      other_ref = make_ref()
      state = %{test_ref => {"foo", "bar"}, other_ref => {1, 2}}

      assert {:noreply, %{^other_ref => {1, 2}}} =
               PlugTracker.handle_info({:DOWN, test_ref, :process, nil, :normal}, state)

      assert [] = HoneylixirTestListener.values()
    end

    test "completes the span when found" do
      HoneylixirTracing.start_span("nice", %{})
      span = Context.current_span()
      test_ref = make_ref()
      state = %{test_ref => {span.trace_id, span.span_id}}

      assert {:noreply, %{}} =
               PlugTracker.handle_info({:DOWN, test_ref, :process, nil, :normal}, state)

      assert [sent_event] = HoneylixirTestListener.values()

      assert %{
               "response.status_code" => "unknown",
               "meta.elixir.process_down_reason" => :normal
             } = sent_event.fields
    end

    test "sets the down reason as :unknown for values that do not implement Jason.Encoder" do
      HoneylixirTracing.start_span("nice", %{})
      span = Context.current_span()
      test_ref = make_ref()
      state = %{test_ref => {span.trace_id, span.span_id}}

      assert {:noreply, %{}} =
               PlugTracker.handle_info(
                 {:DOWN, test_ref, :process, nil, {:cannot, :jasonencode}},
                 state
               )

      assert [sent_event] = HoneylixirTestListener.values()

      assert %{
               "response.status_code" => "unknown",
               "meta.elixir.process_down_reason" => :unknown
             } = sent_event.fields
    end
  end
end
