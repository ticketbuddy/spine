defmodule Spine.EventStore.Postgres.Commit do
  alias Spine.EventStore.Postgres.Schema.Event
  alias Ecto.Multi
  alias Spine.EventStore.Serializer

  def commit(events, cursor) do
    {aggregate_id, key} = cursor

    events
    |> Enum.with_index(key)
    |> Enum.reduce(Multi.new(), fn {event, event_key}, multi ->
      changeset =
        Event.changeset(%{
          data: Serializer.serialize(event),
          aggregate_id: aggregate_id,
          aggregate_number: event_key
        })

      Multi.insert(multi, {:event, event_key}, changeset)
    end)
  end
end
