defmodule HoneylixirTracing.ReaperTest do
  use ExUnit.Case

  test "cleans up expired data in the context table" do
    reaper_pid = start_supervised!({HoneylixirTracing.Reaper, [interval: 100_000_000]})

    span = HoneylixirTracing.Span.setup("cool", %{})
    HoneylixirTracing.Context.set_current_span(span)

    assert :ets.member(:honeylixir_tracing_context, {span.trace_id, span.span_id})

    :timer.sleep(1200)

    Process.send(reaper_pid, :reap, [])

    # Give the Reaper the tiniest bit of time to actually process the message we
    # just sent it
    :timer.sleep(10)

    refute :ets.member(:honeylixir_tracing_context, {span.trace_id, span.span_id})
  end

  test "periodically runs cleanup according to the configured interval" do
    _reaper_pid = start_supervised!({HoneylixirTracing.Reaper, [interval: 150]})

    span = HoneylixirTracing.Span.setup("cool", %{})
    HoneylixirTracing.Context.set_current_span(span)

    assert :ets.member(:honeylixir_tracing_context, {span.trace_id, span.span_id})

    # While we can have the Reaper run sub-ms, we don't let span TTLs be less than
    # a second. So, in order to make sure we pass a TTL we sleep for a second.
    :timer.sleep(1200)

    refute :ets.member(:honeylixir_tracing_context, {span.trace_id, span.span_id})
  end
end
