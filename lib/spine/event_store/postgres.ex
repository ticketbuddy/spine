defmodule Spine.EventStore.Postgres do
  @behaviour Spine.EventStore
  @repo Application.get_env(:spine, :repo)

  alias Spine.EventStore.Postgres.Schema.Event
  alias Ecto.Multi

  def commit(events, cursor) do
    {aggregate_id, key} = cursor

    List.wrap(events)
    |> Enum.with_index(key)
    |> Enum.reduce(Multi.new() fn {aggregate_number, event}, multi ->
      multi
      |> Multi.insert(
        {:event, aggregate_number},
        Event.changeset(persist_event),
        returning: [:event_id, :event_number]
      )
    end)

    @repo.insert()

    :ok
  end

  def seed(event, aggregate_id) do
    :ok
  end

  def all_events() do
    []
  end

  def aggregate_events(aggregate_id) do
    []
  end

  def event(key) do
    # :event
  end
end
