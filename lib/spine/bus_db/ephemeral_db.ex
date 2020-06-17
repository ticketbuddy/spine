defmodule Spine.BusDb.EphemeralDb do
  @moduledoc """
  A mock database that keeps track of subscriptions,
  and the event_number they have processed.
  """
  use GenServer

  @behaviour Spine.BusDb

  @impl true
  def init(opts), do: {:ok, opts}

  def start_link(_opts) do
    init_state = %{}

    GenServer.start_link(__MODULE__, init_state, name: __MODULE__)
  end

  @impl Spine.BusDb
  def subscribe(channel, starting_event_number \\ 0) do
    GenServer.call(__MODULE__, {:subscribe, channel, starting_event_number})
  end

  @impl Spine.BusDb
  def subscriptions do
    GenServer.call(__MODULE__, :subscriptions)
  end

  @impl Spine.BusDb
  def completed(channel, cursor) do
    GenServer.cast(__MODULE__, {:completed, channel, cursor})
  end

  @impl Spine.BusDb
  def cursor(channel) do
    GenServer.call(__MODULE__, {:cursor, channel})
  end

  @impl true
  def handle_call({:subscribe, channel, starting_event_number}, _from, subscriptions) do
    subscriptions = Map.put_new(subscriptions, channel, starting_event_number)

    {:reply, {:ok, 0}, subscriptions}
  end

  @impl true
  def handle_cast({:completed, channel, cursor}, subscriptions) do
    case Map.get(subscriptions, channel) do
      current_cursor when current_cursor == cursor ->
        subscriptions = Map.put(subscriptions, channel, cursor + 1)
        {:noreply, subscriptions}

      _other ->
        {:noreply, subscriptions}
    end
  end

  @impl true
  def handle_call(:subscriptions, _from, subscriptions) do
    {:reply, subscriptions, subscriptions}
  end

  @impl true
  def handle_call({:cursor, channel}, _from, subscriptions) do
    {:reply, Map.get(subscriptions, channel), subscriptions}
  end
end
