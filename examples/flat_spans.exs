defmodule FlatSpans do
  import HoneylixirTracing
  require Integer

  def do_something(value)  when is_integer(value) and rem(value, 2) == 0 do
    with_trace("even numbers", %{"fun_field" => value}, fn ->
      :timer.sleep(:rand.uniform(20))
    end)
  end

  def do_something(_) do
    with_trace("odd numbers", fn ->
      :timer.sleep(:rand.uniform(20))
    end)
  end
end

Enum.each(0..100, fn i ->
  FlatSpans.do_something(i)
end)

# Random waiting to make sure the queue is flushed
:timer.sleep(1000)
