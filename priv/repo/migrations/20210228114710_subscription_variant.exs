defmodule Test.Support.Repo.Migrations.SubscriptionVariant do
  use Ecto.Migration

  def change do
    Spine.BusDb.Postgres.Migration.Subscription.create_variant_field()
  end
end
