defmodule Spine.BusDb.Postgres.Migration.Subscription do
  use Ecto.Migration

  def change do
    create table("spine_subscription", primary_key: false) do
      add(:channel, :string, primary_key: true)
      add(:starting_event_number, :integer, null: false)
      add(:cursor, :integer, null: false)

      timestamps()
    end
  end

  def create_variant_field do
    alter table("spine_subscription") do
      remove(:channel)
      add(:variant, :string, primary_key: true)
      add(:channel, :string, primary_key: true)
    end
  end
end
