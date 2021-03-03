defmodule Spine.Listener.Utils do
  def async_execute_events(events, config) do
    cursor = find_latest_cursor(events)

    completed? =
      events
      |> Enum.map(fn events_chunk ->
        Task.async(fn ->
          Enum.map(events_chunk, fn {event, meta} ->
            # TODO implement retries here, on an individual basis, rather
            # than retrying the entire batch?
            exec_handle_event(event, meta, config)
          end)
          |> Enum.all?(&(&1 == :ok))
        end)
      end)
      |> Task.await_many()
      |> Enum.all?()

    case completed? do
      true ->
        config.spine.completed(config.channel, cursor)
        {:ok, cursor}

      false ->
        :error
    end
  end

  def chunk_by_aggregate(events) do
    Enum.chunk_by(events, fn {_event, meta} ->
      meta.aggregate_id
    end)
  end

  def find_latest_cursor(events) when is_list(events) do
    {_event, meta} = Enum.max_by(List.flatten(events), fn {_event, meta} -> meta.event_number end)
    meta.event_number
  end

  defp exec_handle_event(event, event_meta = %{event_number: cursor}, config) do
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

        config.spine.bus_notifier().broadcast({:listener_completed_event, config.channel, cursor})

        :ok

      other ->
        :telemetry.execute([:spine, :listener, :handle_event, :error], %{count: 1}, %{
          error: other,
          callback: config.callback,
          event: event
        })

        other
    end
  end
end
