defmodule Spine.Listener do
  @moduledoc """
  Is started manually, and receives a notification
  when there is a new event to process.

  Using the config, will dynamically find or start the Listener.Worker
  GenServer, and set it processing a given channel.
  """

  use GenServer

  @default_starting_number 1

  def init(state) do
    {_, config} = state

    send(self(), :subscribe_to_event_store)

    {:ok, config}
  end

  def start_link(
        config = %{
          listener_supervisor: listener_sup,
          notifier: _notifier,
          spine: _event_bus,
          callback: _callback,
          channel: _channel
        }
      ) do
    config = Map.put_new(config, :starting_event_number, @default_starting_number)
    init_state = config

    GenServer.start_link(__MODULE__, init_state, name: {:global, config.channel})
  end

  def handle_info(:subscribe_to_event_store, config) do
    :ok = config.notifier.subscribe()

    {:noreply, config}
  end

  def start_link(_config) do
    raise "Listener must be started with; a dynamic listener supervisor, spine, notifier, callback and a channel."
  end

  def handle_info({:process, aggregate_id}, config) do
    # TODO
    # if listener per aggregate:
    # <channel name>-<aggregate id>
    # if only one listener:
    # <channel name>

    listener_options = %{
      # channel: "#{config.channel}-#{aggregate_id}"
      channel: "#{config.channel}",
      starting_event_number: config.starting_event_number,
      notifier: config.notifier,
      spine: config.spine,
      callback: config.callback
    }

    listener_child_spec = %{
      id: {Listener.Worker, listener_options.channel},
      start: {Listener.Worker, :start_link, [listener_options]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(config.listener_sup, listener_child_spec)

    {:noreply, config}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
