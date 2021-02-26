defmodule Spine.Listener do
  @moduledoc """
  Is started manually, and receives a notification
  when there is a new event to process.

  Using the config, will dynamically find or start the Listener.Worker
  GenServer, and set it processing a given channel.
  """

  use GenServer
  alias __MODULE__

  @default_starting_number 1

  def init(config) do
    send(self(), :subscribe_to_event_store)

    {:ok, config}
  end

  def start_link(
        config = %{
          listener_supervisor: _listener_sup,
          notifier: _notifier,
          spine: _event_bus,
          callback: _callback
        }
      ) do
    config = Map.put_new(config, :starting_event_number, @default_starting_number)
    init_state = config

    GenServer.start_link(__MODULE__, init_state, name: {:global, config.callback.root_channel()})
  end

  def handle_info(:subscribe_to_event_store, config) do
    :ok = config.notifier.subscribe()

    {:noreply, config}
  end

  def handle_info({:process, aggregate_id}, config) do
    listener_options = %{
      channel: config.callback.channel(aggregate_id),
      starting_event_number: config.starting_event_number,
      spine: config.spine,
      callback: config.callback
    }

    listener_child_spec = %{
      id: {Listener.Worker, listener_options.channel},
      start: {Listener.Worker, :start_link, [listener_options]},
      restart: :temporary
    }

    {:ok, pid} = find_or_start_worker(config.listener_supervisor, listener_child_spec)

    send(pid, :process)

    {:noreply, config}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp find_or_start_worker(worker_supervisor, child_spec) do
    case DynamicSupervisor.start_child(worker_supervisor, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end
end
