defmodule Spine.Listener do
  use GenServer

  @default_starting_number 1

  def init(state) do
    {_, config} = state

    send(self(), :subscribe)

    {:ok, {nil, config}}
  end

  def start_link(
        config = %{notifier: _notifier, spine: _event_bus, callback: _callback, channel: _channel}
      ) do
    config = Map.put_new(config, :starting_event_number, @default_starting_number)
    init_state = {config.starting_event_number, config}

    GenServer.start_link(__MODULE__, init_state, name: {:global, config.channel})
  end

  def handle_info(:subscribe, {_cursor, config}) do
    {:ok, cursor} = config.spine.subscribe(config.channel, config.starting_event_number)

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

        {:ok, event, event_meta = %{event_number: cursor}} ->
          :telemetry.execute([:spine, :listener, :fetched_event], %{count: 1}, %{
            cursor: cursor,
            callback: config.callback,
            event: event
          })

          cursor = handle_event(event, event_meta, config)

          schedule_work()

          cursor
      end

    {:noreply, {cursor, config}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  def schedule_work do
    send(self(), :process)
  end

  defp handle_event(event, event_meta = %{event_number: cursor}, config) do
    meta = %{
      channel: config.channel,
      cursor: cursor,
      occured_at: event_meta.inserted_at
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
