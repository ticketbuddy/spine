defmodule App.ReadModel do
  @behaviour Spine.Listener.Callback

  @impl true
  def handle_event(event = %App.FundsAdded{}, meta) do
    :timer.sleep(event.sleep_for)
    send(event.reply_pid, {:handling_event, DateTime.utc_now(), [event, meta]})

    :ok
  end

  @impl true
  def handle_event(_event, _meta), do: :ok
end
