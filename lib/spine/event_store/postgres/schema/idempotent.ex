defmodule Spine.EventStore.Postgres.Schema.Idempotent do
  use Ecto.Schema
  @primary_key {:idempotent_id, :binary_id, autogenerate: true}

  schema "spine_idempotent" do
    field(:key, :string)
  end

  def changeset(params) do
    import Ecto.Changeset

    %__MODULE__{}

    %__MODULE__{}
    |> cast(params, [:key])
    |> validate_required([:key])
    |> unique_constraint([:key], name: :idempotency_lock)
  end
end
