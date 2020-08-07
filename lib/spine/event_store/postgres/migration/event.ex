defmodule Spine.EventStore.Postgres.Migration.Event do
  use Ecto.Migration

  def change do
    create table("spine_event", primary_key: false) do
      add(:event_id, :uuid, primary_key: true, null: false)
      add(:aggregate_id, :string, null: false)
      add(:event_number, :bigserial)
      add(:aggregate_number, :integer, null: false)
      add(:data, :binary, null: false)

      timestamps()
    end

    create(
      unique_index(
        :spine_event,
        [:aggregate_id, :aggregate_number],
        name: :aggregate_locking
      )
    )
  end
end
