defmodule Test.Support.Repo.Migrations.Subscription do
  use Ecto.Migration

  def change do
    Spine.BusDb.Postgres.Migration.Subscription.change()
  end
end
