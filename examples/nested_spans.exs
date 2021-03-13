defmodule NestedSpans do
  import HoneylixirTracing
  require Integer

  def do_something(value) when is_integer(value) and rem(value, 3) == 0 do
    with_trace("three divides", %{"initial" => value}, fn ->
      Process.sleep(:rand.uniform(10) + 2)
      do_something(value + 1)
      with_trace("random wait", fn ->
        Process.sleep(:rand.uniform(12) + 5)
      end)
      Process.sleep(:rand.uniform(10) + 2)
    end)
  end

  def do_something(value) when is_integer(value) and rem(value, 2) == 0 do
    with_trace("two not three numbers", %{"5x" => value}, fn ->
      Process.sleep(:rand.uniform(20))
      do_something(value + 1)
    end)
  end

  def do_something(value) when is_integer(value) do
    with_trace("remaining", %{"last" => value}, fn ->
      Process.sleep(:rand.uniform(20))
    end)
  end
end

Enum.each(521..530, fn i ->
  NestedSpans.do_something(i)
end)

# Random waiting to make sure the queue is flushed
Process.sleep(5000)
