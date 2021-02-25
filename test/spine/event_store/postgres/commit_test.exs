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
               }, [{:returning, [:event_number]}]}},
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
               }, [{:returning, [:event_number]}]}}
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

  describe "latest_event_number/1" do
    setup do
      %{
        results_with_idempotency: %{
          {:idempotent_check} => %Spine.EventStore.Postgres.Schema.Idempotent{
            idempotent_id: "ed43af55-98f2-4f6b-86a9-946a8ab3934d",
            key: "only-once-please"
          },
          {:event, 1} => %Spine.EventStore.Postgres.Schema.Event{
            aggregate_id: "aggregate-12345",
            aggregate_number: 1,
            data: %TestApp.Incremented{count: 1},
            event_id: "ffca880c-841c-4aa8-9ab3-8645d42d485a",
            event_number: 113,
            inserted_at: ~U[2021-02-25 12:17:53Z],
            updated_at: ~U[2021-02-25 12:17:53Z]
          }
        },
        results_no_idempotency: %{
          {:event, 1} => %Spine.EventStore.Postgres.Schema.Event{
            aggregate_id: "aggregate-12345",
            aggregate_number: 1,
            data: %TestApp.Incremented{count: 1},
            event_id: "6c6292c7-4d9c-4ba0-95d8-c38cfad2a8cd",
            event_number: 219,
            inserted_at: ~U[2021-02-25 10:16:57Z],
            updated_at: ~U[2021-02-25 10:16:57Z]
          },
          {:event, 2} => %Spine.EventStore.Postgres.Schema.Event{
            aggregate_id: "aggregate-12345",
            aggregate_number: 2,
            data: %TestApp.Incremented{count: 1},
            event_id: "5ebac3d7-99a0-4234-b9e3-79f00fb5dbf9",
            event_number: 220,
            inserted_at: ~U[2021-02-25 10:16:57Z],
            updated_at: ~U[2021-02-25 10:16:57Z]
          }
        }
      }
    end

    test "from a successful set of results, returns latest event number", %{
      results_no_idempotency: results
    } do
      assert 220 == Commit.latest_event_number(results)
    end

    test "from a successful result which includes inserting idempotency key", %{
      results_with_idempotency: results
    } do
      assert 113 == Commit.latest_event_number(results)
    end
  end
end
