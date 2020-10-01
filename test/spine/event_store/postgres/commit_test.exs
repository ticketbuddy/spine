defmodule Spine.EventStore.Postgres.CommitTest do
  use ExUnit.Case
  alias Spine.EventStore.Postgres.Commit

  test "builds multi, with multiple events to insert" do
    events = [:one, :two]
    cursor = {"agg-12345", 0}
    opts = []

    assert [
             {{:event, 0},
              {:insert,
               %Ecto.Changeset{
                 action: :insert,
                 changes: %{
                   aggregate_id: "agg-12345",
                   aggregate_number: 0,
                   data: :one
                 },
                 errors: [],
                 data: %Spine.EventStore.Postgres.Schema.Event{},
                 valid?: true
               }, []}},
             {{:event, 1},
              {:insert,
               %Ecto.Changeset{
                 action: :insert,
                 changes: %{
                   aggregate_id: "agg-12345",
                   aggregate_number: 1,
                   data: :two
                 },
                 errors: [],
                 data: %Spine.EventStore.Postgres.Schema.Event{},
                 valid?: true
               }, []}}
           ] = Commit.commit(events, cursor, opts) |> Ecto.Multi.to_list()
  end

  test "when idempotent_key is provided, then idempotency check is added to the transaction" do
    events = [:one, :two]
    cursor = {"agg-12345", 0}
    opts = [idempotent_key: "only-do-once"]

    assert {{:idempotent_check},
            {:insert,
             %Ecto.Changeset{
               action: :insert,
               changes: %{key: "only-do-once"},
               errors: [],
               valid?: true
             }, []}} = Commit.commit(events, cursor, opts) |> Ecto.Multi.to_list() |> List.last()
  end
end
