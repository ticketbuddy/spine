defmodule Spine.EventStore.Ephemeral do
  use GenServer
  @behaviour Spine.EventStore

  def init(opts), do: {:ok, opts}

  def start_link(_opts) do
    init_state = []
    GenServer.start_link(__MODULE__, init_state, name: __MODULE__)
  end

  @impl Spine.EventStore
  def commit(events, cursor) do
    GenServer.call(__MODULE__, {:commit, List.wrap(events), cursor})
  end

  @impl Spine.EventStore
  def all_events do
    GenServer.call(__MODULE__, :all_events)
  end

  @impl Spine.EventStore
  def aggregate_events(aggregate_id) do
    GenServer.call(__MODULE__, {:aggregate_events, aggregate_id})
  end

  @impl Spine.EventStore
  def event(event_number) do
    GenServer.call(__MODULE__, {:event, event_number})
  end

  def handle_call({:commit, new_events, cursor}, _from, events) do
    {aggregate_id, key} = cursor
    events_on_aggregate = events_for_aggregate(events, aggregate_id)

    new_events = Enum.map(new_events, &{aggregate_id, &1})

    case Enum.count(events_on_aggregate) == key do
      true -> {:reply, :ok, events ++ new_events}
      false -> {:reply, :incorrect_key, events}
    end
  end

  def handle_call(:all_events, _from, events) do
    {:reply, events, events}
  end

  def handle_call({:event, event_number}, _from, events) do
    {:reply, Enum.at(events, event_number), events}
  end

  def handle_call({aggregate_events, aggregate_id}, _from, events) do
    {:reply, events_for_aggregate(events, aggregate_id), events}
  end

  defp events_for_aggregate(events, aggregate_id) do
    Enum.filter(events, fn {agg_id, _event} -> agg_id == aggregate_id end)
  end
end
