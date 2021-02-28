defmodule Spine.BusDb.Postgres.Schema.Subscription do
  use Ecto.Schema
  @primary_key false
  @timestamps_opts [type: :utc_datetime]

  schema "spine_subscription" do
    field(:channel, :string, primary_key: true)
    field(:variant, :string, primary_key: true)
    field(:starting_event_number, :integer)
    field(:cursor, :integer)

    timestamps()
  end

  def changeset(params) do
    import Ecto.Changeset

    %__MODULE__{}
    |> cast(params, [:channel, :variant, :starting_event_number, :cursor, :channel])
    |> validate_required([:channel, :variant, :starting_event_number, :cursor, :channel])
    |> unique_constraint(:channel, name: :spine_subscription_pkey)
  end
end
