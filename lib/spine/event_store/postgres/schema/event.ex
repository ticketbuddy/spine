defmodule Spine.EventStore.Postgres.Schema.Event do
  use Ecto.Schema
  @primary_key {:event_id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "spine_event" do
    field(:aggregate_id, :string)
    field(:event_number, :integer)
    field(:aggregate_number, :integer)
    field(:data, :string)

    timestamps()
  end

  def changeset(event) do
    import Ecto.Changeset

    %__MODULE__{}
    |> cast(params, [:data, :aggregate_id, :aggregate_number, :idempotency_key])
    |> validate_required([:data, :aggregate_id, :aggregate_number, :idempotency_key])
    |> unique_constraint(:out_of_sync_with_event_store,
      name: :headwater_events_aggregate_id_event_id_index
    )
  end
end
