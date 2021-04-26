defmodule CrossProcessExample.KvStore do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def lookup(key) do
    GenServer.call(__MODULE__, {:lookup, key, HoneylixirTracing.current_propagation_context()})
  end

  def add(key, value) do
    GenServer.cast(__MODULE__, {:add, key, value})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:lookup, key, ctx}, _from, keys) do
    HoneylixirTracing.span(ctx, "KvStore.lookup", %{"pid" => inspect(self())}, fn ->
      {:reply, Map.get(keys, key), keys}
    end)
  end

  @impl true
  def handle_cast({:add, key, value}, keys) do
    {:noreply, Map.put(keys, key, value)}
  end
end
