defmodule Spine.Listener do
  use GenServer
  import Logger

  def init(state) do
    {_, config} = state

    send(self(), :subscribe)

    {:ok, {nil, config}}
  end

  def start_link(
        config = %{notifier: _notifier, spine: _event_bus, callback: _callback, channel: _channel}
      ) do
    init_state = {1, config}
    GenServer.start_link(__MODULE__, init_state, name: {:global, config.channel})
  end

  def handle_info(:subscribe, {_cursor, config}) do
    {:ok, cursor} = config.spine.subscribe(config.channel)

    :ok = config.notifier.subscribe()

    schedule_work()

    {:noreply, {cursor, config}}
  end

  def start_link(_config) do
    raise "Listener must be started with; spine, notifier, callback and a channel."
  end

  def handle_info(:process, state) do
    {cursor, config} = state

    cursor =
      case config.spine.next_event(cursor) do
        {:ok, :no_next_event} ->
          :telemetry.execute([:spine, :listener, :missed_event], %{count: 1}, %{
            cursor: cursor,
            callback: config.callback
          })

          cursor

        {:ok, cursor, event} ->
          :telemetry.execute([:spine, :listener, :fetched_event], %{count: 1}, %{
            cursor: cursor,
            callback: config.callback,
            event: event
          })

          cursor = handle_event(event, cursor, config)

          schedule_work()

          cursor
      end

    {:noreply, {cursor, config}}
  end

  def schedule_work do
    send(self(), :process)
  end

  defp handle_event(event, cursor, config) do
    meta = %{
      channel: config.channel,
      cursor: cursor
    }

    case config.callback.handle_event(event, meta) do
      :ok ->
        :telemetry.execute([:spine, :listener, :handle_event, :ok], %{count: 1}, %{
          callback: config.callback,
          event: event
        })

        config.spine.completed(config.channel, cursor)
        cursor + 1

      other ->
        :telemetry.execute([:spine, :listener, :handle_event, :error], %{count: 1}, %{
          error: other,
          callback: config.callback,
          event: event
        })

        cursor
    end
  end
end
