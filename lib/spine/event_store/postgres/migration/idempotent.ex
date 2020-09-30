defmodule Spine.EventStore.Postgres.Migration.Idempotent do
  use Ecto.Migration

  def change do
    create table("spine_idempotent", primary_key: false) do
      add(:idempotent_id, :uuid, primary_key: true, null: false)
      add(:key, :string, null: false)
    end

    create(
      unique_index(
        :spine_event,
        [:key],
        name: :idempotency_lock
      )
    )
  end
end
