defmodule Spine.Listener.Utils do
  def async_execute_events(events, config) do
    cursor = find_latest_cursor(events)

    completed? =
      events
      |> Enum.map(fn events_chunk ->
        Task.async(fn ->
          Enum.map(events_chunk, fn {event, meta} ->
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

  defp exec_handle_event(event, event_meta, config, attempt \\ 0)

  defp exec_handle_event(event, event_meta, config, attempt) when attempt > 4 do
    :telemetry.execute([:spine, :listener, :handle_event, :max_retry_reached], %{count: 1}, %{
      msg: "Max retry limit reached in event handler.",
      callback: config.callback,
      event: event,
      event_meta: event_meta,
      attempt: attempt
    })

    {:error, :max_listener_callback_limit_reached}
  end

  defp exec_handle_event(event, event_meta = %{event_number: cursor}, config, attempt) do
    retry_back_off(attempt)

    meta = %{
      channel: config.channel,
      cursor: cursor,
      occured_at: event_meta.inserted_at,
      attempt: attempt + 1
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

        exec_handle_event(event, event_meta, config, attempt + 1)
    end
  end

  defp retry_back_off(attempt), do: :timer.sleep(attempt * (100 - jitter()))

  defp jitter, do: :rand.uniform(40)
end
