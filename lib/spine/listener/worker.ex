defmodule Spine.Listener.Worker do
  use GenServer

  def init(state) do
    {_, config} = state

    send(self(), :subscribe_to_bus)

    {:ok, {nil, config}}
  end

  def start_link(
        config = %{
          starting_event_number: _starting_event_number,
          spine: _event_bus,
          callback: _callback,
          channel: _channel,
          variant: _variant
        }
      ) do
    init_state = {config.starting_event_number, config}

    GenServer.start_link(__MODULE__, init_state,
      name: {:global, "#{config.channel}-#{config.variant}"}
    )
  end

  def start_link(_config) do
    raise "Listener must be started with; variant, spine, callback and a channel."
  end

  def handle_info(:subscribe_to_bus, {_cursor, config}) do
    {:ok, cursor} =
      config.spine.subscribe(config.channel, config.variant, config.starting_event_number)

    {:noreply, {cursor, config}}
  end

  def handle_info(:process, state) do
    {cursor, config} = state

    next_event_opts =
      case config.variant do
        "single" -> []
        vairant -> [by_variant: vairant]
      end

    case config.spine.next_event(cursor, next_event_opts) do
      {:ok, :no_next_event} ->
        :telemetry.execute([:spine, :listener, :missed_event], %{count: 1}, %{
          cursor: cursor,
          callback: config.callback
        })

        {:stop, :normal, {cursor, config}}

      {:ok, event, event_meta = %{event_number: cursor}} ->
        :telemetry.execute([:spine, :listener, :fetched_event], %{count: 1}, %{
          cursor: cursor,
          callback: config.callback,
          event: event
        })

        cursor = handle_event(event, event_meta, config)

        schedule_work()

        {:noreply, {cursor, config}}
    end
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

        config.spine.completed(config.channel, config.variant, cursor)
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
