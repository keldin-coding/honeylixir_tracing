defmodule HoneylixirTracingTest do
  use ExUnit.Case
  doctest HoneylixirTracing

  test "greets the world" do
    assert HoneylixirTracing.hello() == :world
  end
end
