defmodule Spine.Bus.Ephemeral do
  use GenServer

  def init(opts), do: {:ok, opts}

  def start_link(_opts) do
    init_state = %{}
    GenServer.start_link(__MODULE__, init_state, name: __MODULE__)
  end

  def subscribe(channel, pid \\ self()) do
    GenServer.cast(__MODULE__, {:subscribe, channel, pid})
  end

  def subscriptions do
    GenServer.call(__MODULE__, :subscriptions)
  end

  def completed(channel, cursor) do
    GenServer.cast(__MODULE__, {:completed, channel, cursor})
  end

  def cursor(channel) do
    GenServer.call(__MODULE__, {:cursor, channel})
  end

  def handle_cast({:subscribe, channel, pid}, subscriptions) do
    subscriptions = Map.put_new(subscriptions, channel, {pid, 0})

    {:noreply, subscriptions}
  end

  def handle_cast({:completed, channel, cursor}, subscriptions) do
    case Map.get(subscriptions, channel) do
      {pid, current_cursor} when current_cursor == cursor ->
        subscriptions = Map.put(subscriptions, channel, {pid, cursor + 1})
        {:noreply, subscriptions}

      _other ->
        {:noreply, subscriptions}
    end
  end

  def handle_call(:subscriptions, _from, subscriptions) do
    {:reply, subscriptions, subscriptions}
  end

  def handle_call({:cursor, channel}, _from, subscriptions) do
    {_pid, cursor} = Map.get(subscriptions, channel)
    {:reply, cursor, subscriptions}
  end
end
