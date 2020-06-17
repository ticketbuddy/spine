defmodule Spine.Listener do
  use GenServer
  import Logger

  def init(state) do
    {_, config} = state
    {:ok, cursor} = Spine.BusDb.EphemeralDb.subscribe(config.channel)

    schedule_work()

    {:ok, {cursor, config}}
  end

  def start_link(config) do
    init_state = {0, config}
    GenServer.start_link(__MODULE__, init_state, name: {:global, config.channel})
  end

  def handle_info(:process, state) do
    {cursor, config} = state

    {_aggregate_id, event} = config.event_store.event(cursor)

    case config.callback.handle_event(event) do
      :ok ->
        config.bus_db.completed(config.channel, cursor)
        schedule_work()
        {:noreply, {cursor + 1, config}}

      other ->
        Logger.error("#{config.callback} returned error:\n" <> inspect(other))
        {:noreply, state}
    end
  end

  def schedule_work do
    Process.send_after(self(), :process, 500)
  end
end
