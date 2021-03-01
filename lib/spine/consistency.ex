defmodule Spine.Consistency do
  def wait_for_event(notifier, [channel], event_number, timeout) do
    notifier.subscribe()

    consistency_result = do_wait(channel, event_number, timeout)

    consistency_result
  end

  def wait_for_event(_notifier, _channels, _event_number, _timeout) do
    raise "Spine currently only supports strong consistency for one channel"
  end

  defp do_wait(channel, event_number, timeout) do
    receive do
      {:listener_completed_event, ^channel, ^event_number} -> :ok
    after
      timeout -> {:timeout, event_number}
    end
  end
end
