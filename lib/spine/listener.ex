defmodule Spine.Listener do
  use GenServer
  import Logger

  def init(state) do
    {_, config} = state
    :ok = Spine.BusDb.EphemeralDb.subscribe(config.channel)

    {:ok, state}
  end

  def start_link(config) do
    init_state = {%{}, config}
    GenServer.start_link(__MODULE__, init_state, name: {:global, config.channel})
  end

  def handle_cast({:process, event_number}, state) do
    {%{}, config} = state

    {aggregate_id, event} = config.event_store.event(event_number)

    case config.callback.handle_event(event) do
      :ok -> config.bus_db.completed(config.channel, event_number)
      other -> Logger.error("#{config.callback} returned error:\n" <> inspect(other))
    end

    {:noreply, state}
  end
end
