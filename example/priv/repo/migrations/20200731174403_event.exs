defmodule Example.Repo.Migrations.Event do
  use Ecto.Migration

  def change do
    Spine.EventStore.Postgres.Migration.Event.change()
  end
end
