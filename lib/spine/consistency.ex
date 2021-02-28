defmodule Spine.Consistency do
  def wait_for_event(aggregate_id, notifier, [listener_callback], event_number, timeout) do
    notifier.subscribe()

    channel = listener_callback.channel()
    variant = listener_callback.variant(aggregate_id)

    consistency_result = do_wait(channel, variant, event_number, timeout)

    consistency_result
  end

  def wait_for_event(_aggregate_id, _notifier, _channels, _event_number, _timeout) do
    raise "Spine currently only supports strong consistency for one channel"
  end

  defp do_wait(channel, variant, event_number, timeout) do
    receive do
      {:listener_completed_event, ^channel, ^variant, ^event_number} ->
        :ok
    after
      timeout -> {:timeout, event_number}
    end
  end
end
