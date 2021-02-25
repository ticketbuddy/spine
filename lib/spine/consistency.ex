defmodule Spine.Consistency do
  @moduledoc """
  Poll listener progress, and broadcast the event_number they have
  most recently processed at that point.
  """

  use GenServer

  @poll_time_ms 1_000
  @default_server_name __MODULE__

  @impl true
  def init(config) do
    send(self(), :do_poll)

    {:ok, config}
  end

  @impl true
  def start_link(config = %{notifier: _notifier, spine: _spine}) do
    name = Map.get(config, :name, @default_server_name)
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @impl true
  def handle_info(:do_poll, config = %{notifier: notifier, spine: spine}) do
    notifier.broadcast({:listener_progress_update, spine.subscriptions()})

    schedule_work()

    {:noreply, config}
  end

  @impl true
  def handle_call(:get_notifier, _from, config) do
    {:reply, config.notifier, config}
  end

  def wait_for_event(event_number, timeout, server \\ @default_server_name) do
    notifier = GenServer.call(server, :get_notifier)

    notifier.subscribe()

    consistency_result = do_wait(event_number, timeout)

    consistency_result
  end

  defp do_wait(event_number, timeout) do
    receive do
      {:listener_progress_update, subscriptions} ->
        subscriptions
        |> Map.values()
        |> Enum.all?(&(&1 >= event_number))
        |> case do
          true -> :ok
          false -> do_wait(event_number, timeout)
        end
    after
      timeout -> {:timeout, event_number}
    end
  end

  defp schedule_work, do: Process.send_after(self(), :do_poll, @poll_time_ms)
end
