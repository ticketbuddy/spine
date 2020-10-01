defmodule Test.Support.Repo.Migrations.Idempotent do
  use Ecto.Migration

  def change do
    Spine.EventStore.Postgres.Migration.Idempotent.change()
  end
end
