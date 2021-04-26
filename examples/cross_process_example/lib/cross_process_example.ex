defmodule CrossProcessExample do
  @moduledoc """
  Documentation for `CrossProcessExample`.
  """

  alias CrossProcessExample.KvStore

  def put_value(k, v) do
    HoneylixirTracing.span("put_value", %{"cross_process" => true, "pid" => inspect(self())}, fn ->
      KvStore.add(k, v)
    end)
  end

  def get_value(k) do
    HoneylixirTracing.span("get_value", %{"cross_process" => true, "pid" => inspect(self())}, fn ->
      KvStore.lookup(k)
    end)
  end
end
