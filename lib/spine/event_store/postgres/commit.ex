defmodule Spine.EventStore.Postgres.Commit do
  alias Spine.EventStore.Postgres.Schema.{Event, Idempotent}
  alias Ecto.Multi

  def commit(events, cursor, opts) do
    {aggregate_id, key} = cursor
    idempotent_key = Keyword.get(opts, :idempotent_key)

    events
    |> Enum.with_index(key)
    |> Enum.reduce(Multi.new(), fn {event, event_key}, multi ->
      changeset =
        Event.changeset(%{
          data: event,
          aggregate_id: aggregate_id,
          aggregate_number: event_key
        })

      Multi.insert(multi, {:event, event_key}, changeset, returning: [:event_number])
    end)
    |> ensure_idempotency(idempotent_key)
  end

  @spec latest_event_number(Map.t()) :: Integer.t()
  def latest_event_number(results) do
    results
    |> Map.values()
    |> get_in([Access.all(), Access.key(:event_number)])
    |> Enum.max()
  end

  defp ensure_idempotency(multi, nil), do: multi

  defp ensure_idempotency(multi, idempotent_key) do
    changeset = Idempotent.changeset(%{key: idempotent_key})
    Multi.insert(multi, {:idempotent_check}, changeset)
  end
end
