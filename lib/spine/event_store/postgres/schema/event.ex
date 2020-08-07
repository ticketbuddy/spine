defmodule Spine.EventStore.Postgres.Schema.Event do
  use Ecto.Schema
  @primary_key {:event_id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "spine_event" do
    field(:aggregate_id, :string)
    field(:event_number, :integer)
    field(:aggregate_number, :integer)
    field(:data, Spine.EventStore.Postgres.Term)

    timestamps()
  end

  def changeset(params) do
    import Ecto.Changeset

    %__MODULE__{}
    |> cast(params, [:data, :aggregate_id, :aggregate_number])
    |> validate_required([:data, :aggregate_id, :aggregate_number])
    |> unique_constraint([:aggregate_id, :aggregate_number],
      name: :aggregate_locking
    )
  end
end
