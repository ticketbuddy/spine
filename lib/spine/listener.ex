defmodule Spine.Listener do
  use GenServer
  import Logger

  def init(state) do
    {_, config} = state
    {:ok, cursor} = config.spine.subscribe(config.channel)

    send(self(), :process)

    {:ok, {cursor, config}}
  end

  def start_link(config) do
    init_state = {0, config}
    GenServer.start_link(__MODULE__, init_state, name: {:global, config.channel})
  end

  def handle_info(:process, state) do
    {cursor, config} = state

    cursor =
      case config.spine.event(cursor) do
        nil -> cursor
        event -> handle_event(event, cursor, config)
      end

    schedule_work()
    {:noreply, {cursor, config}}
  end

  def schedule_work do
    Process.send_after(self(), :process, 50)
  end

  defp handle_event(event, cursor, config) do
    case config.callback.handle_event(event) do
      :ok ->
        config.spine.completed(config.channel, cursor)
        cursor + 1

      other ->
        Logger.error("#{config.callback} returned error:\n" <> inspect(other))

        cursor
    end
  end
end
