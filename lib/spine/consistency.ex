defmodule Spine.Consistency do
  @moduledoc """
  Poll listener progress, and broadcast the event_number they have
  most recently processed at that point.
  """

  use GenServer

  @poll_time_ms 1_000

  @impl true
  def init(config) do
    send(self(), :do_poll)

    {:ok, config}
  end

  @impl true
  def start_link(config = %{notifier: _notifier, spine: _spine}) do
    name = Map.get(config, :name, __MODULE__)
    GenServer.start_link(__MODULE__, config, name: name)
  end

  def handle_info(:do_poll, config = %{notifier: notifier, spine: spine}) do
    notifier.broadcast({:listener_progress_update, spine.subscriptions()})

    schedule_work()

    {:noreply, config}
  end

  defp schedule_work, do: Process.send_after(self(), :do_poll, @poll_time_ms)
end
