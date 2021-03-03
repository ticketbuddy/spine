defmodule Spine.Listener do
  use GenServer

  @default_starting_number 1

  alias Spine.Listener.Utils

  def init(state) do
    {_, config} = state

    send(self(), :subscribe)

    {:ok, {nil, config}}
  end

  def start_link(config = %{spine: _spine, callback: _callback, channel: _channel}) do
    config = Map.put_new(config, :starting_event_number, @default_starting_number)
    init_state = {config.starting_event_number, config}

    GenServer.start_link(__MODULE__, init_state, name: {:global, config.channel})
  end

  def handle_info(:subscribe, {_cursor, config}) do
    {:ok, cursor} = config.spine.subscribe(config.channel, config.starting_event_number)

    :ok = config.spine.commit_notifier().subscribe()

    schedule_work()

    {:noreply, {cursor, config}}
  end

  def start_link(_config) do
    raise "Listener must be started with; spine, callback and a channel."
  end

  def handle_info(:process, state) do
    {cursor, config} = state

    cursor =
      case config.spine.next_event(cursor) do
        {:ok, :no_next_event} ->
          cursor

        {:ok, event, event_meta = %{event_number: original_cursor}} ->
          next_cursor =
            case Spine.Listener.Utils.async_execute_events([{event, event_meta}], config) do
              {:ok, last_processed_cursor} -> last_processed_cursor + 1
              :error -> original_cursor
            end

          schedule_work()

          next_cursor
      end

    {:noreply, {cursor, config}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  def schedule_work do
    send(self(), :process)
  end
end
