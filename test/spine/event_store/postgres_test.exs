defmodule Spine.EventStore.PostgresTest do
  use ExUnit.Case
  use Test.Support.Mox
  use Test.Support.Helper, repo: Test.Support.Repo

  defmodule PostgresTestDb do
    use Spine.EventStore.Postgres, repo: Test.Support.Repo, notifier: ListenerNotifierMock
  end

  setup do
    Mox.stub(ListenerNotifierMock, :broadcast, fn {:process, _aggregate_id} -> :ok end)

    :ok
  end

  @next_event_opts []

  describe "committing events" do
    test "commits a single event" do
      event = %TestApp.Incremented{}
      cursor = {"aggregate-12345", 1}

      assert {:ok, event_number} = PostgresTestDb.commit(event, cursor, [])
      assert is_integer(event_number)
    end

    test "broadcasts message after a commit has been processed" do
      ListenerNotifierMock
      |> Mox.expect(:broadcast, fn {:process, "aggregate-12345"} -> :ok end)

      event = %TestApp.Incremented{}
      cursor = {"aggregate-12345", 1}

      assert {:ok, event_number} = PostgresTestDb.commit(event, cursor, [])
      assert is_integer(event_number)
    end

    test "commits multiple events" do
      events = [%TestApp.Incremented{}, %TestApp.Incremented{}]
      cursor = {"aggregate-12345", 1}

      assert {:ok, event_number} = PostgresTestDb.commit(events, cursor, [])
      assert is_integer(event_number)
    end

    test "when cursor points to an already written event" do
      events = [%TestApp.Incremented{}, %TestApp.Incremented{}]
      cursor_one = {"aggregate-12345", 1}
      cursor_two = {"aggregate-12345", 2}

      assert {:ok, event_number} = PostgresTestDb.commit(events, cursor_one, [])
      assert is_integer(event_number)
      assert :error == PostgresTestDb.commit(events, cursor_two, [])
    end

    test "respects idempotent_key when provided" do
      events = [%TestApp.Incremented{}]
      cursor_one = {"aggregate-12345", 1}
      cursor_two = {"aggregate-12345", 2}

      assert {:ok, event_number} =
               PostgresTestDb.commit(events, cursor_one, idempotent_key: "only-once-please")

      assert is_integer(event_number)

      assert {:ok, :idempotent} ==
               PostgresTestDb.commit(events, cursor_two, idempotent_key: "only-once-please")
    end
  end

  describe "fetches events" do
    setup do
      PostgresTestDb.commit(%TestApp.Incremented{count: 5}, {"aggregate-12345", 1}, [])
      PostgresTestDb.commit(%TestApp.Incremented{count: 10}, {"aggregate-12345", 2}, [])
      PostgresTestDb.commit(%TestApp.Incremented{count: 15}, {"aggregate-12345", 3}, [])

      PostgresTestDb.commit(%TestApp.Incremented{count: 20}, {"aggregate-6789", 1}, [])
      PostgresTestDb.commit(%TestApp.Incremented{count: 25}, {"aggregate-6789", 2}, [])
      PostgresTestDb.commit(%TestApp.Incremented{count: 30}, {"aggregate-6789", 3}, [])

      :ok
    end

    test "fetches all events" do
      assert [
               # seeded event
               %TestApp.Incremented{count: 1},
               %TestApp.Incremented{count: 1},
               %TestApp.Incremented{count: 1},
               %TestApp.Incremented{count: 1},
               %TestApp.Incremented{count: 5},
               %TestApp.Incremented{count: 10},
               %TestApp.Incremented{count: 15},
               %TestApp.Incremented{count: 20},
               %TestApp.Incremented{count: 25},
               %TestApp.Incremented{count: 30}
             ] == PostgresTestDb.all_events()
    end

    test "fetches events by aggregate_id" do
      assert [
               %TestApp.Incremented{count: 20},
               %TestApp.Incremented{count: 25},
               %TestApp.Incremented{count: 30}
             ] == PostgresTestDb.aggregate_events("aggregate-6789")
    end

    test "fetches a single event by event_number" do
      assert %TestApp.Incremented{count: 1} == PostgresTestDb.event(1)
    end

    test "fetches the next event" do
      event_number = 2

      assert {:ok, %TestApp.Incremented{}, %{event_number: 2, inserted_at: %DateTime{}}} =
               PostgresTestDb.next_event(event_number, @next_event_opts)
    end

    test "fetches the next event, when there is a gap" do
      event_number = 3

      assert {:ok, %TestApp.Incremented{}, %{event_number: 4, inserted_at: %DateTime{}}} =
               PostgresTestDb.next_event(event_number, @next_event_opts)
    end

    test "when there is not a next_event" do
      event_number = 6_234

      assert {:ok, :no_next_event} == PostgresTestDb.next_event(event_number, @next_event_opts)
    end

    test "when individual event is not found" do
      assert nil == PostgresTestDb.event(-50)
    end

    test "fetches next event for by_variant channel type" do
      # event_number = 1
      aggregate_1_id = "basic-aggregate"
      aggregate_2_id = "aggregate-for-channel"

      {:ok, event_number} =
        PostgresTestDb.commit(%TestApp.Incremented{count: 777}, {aggregate_1_id, 1}, [])

      {:ok, expected_next_event} =
        PostgresTestDb.commit(%TestApp.Incremented{count: 333}, {aggregate_2_id, 1}, [])

      assert {:ok, _event, %{event_number: retrieved_event_id_by_variant}} =
               PostgresTestDb.next_event(event_number, by_variant: aggregate_2_id)

      assert {:ok, _event, %{event_number: retrieved_event_id}} =
               PostgresTestDb.next_event(event_number, [])

      assert expected_next_event == retrieved_event_id_by_variant
      assert expected_next_event != retrieved_event_id
    end
  end

  describe "fetches aggregates" do
    setup do
      for index <- 0..15 do
        PostgresTestDb.commit(%TestApp.Incremented{count: 9}, {"aggregate-#{index}", 1}, [])
      end

      :ok
    end

    test "returns all aggregates in batches of 10" do
      test_pid = self()

      cb = fn batch ->
        send(test_pid, {:received_batch, batch})
      end

      assert {:ok, :ok} == PostgresTestDb.all_aggregates(cb)

      assert_receive(
        {:received_batch,
         [
           "seeded-aggregate-1",
           "seeded-aggregate-2",
           "aggregate-0",
           "aggregate-1",
           "aggregate-10",
           "aggregate-11",
           "aggregate-12",
           "aggregate-13",
           "aggregate-14",
           "aggregate-15"
         ]}
      )

      assert_receive(
        {:received_batch,
         [
           "aggregate-2",
           "aggregate-3",
           "aggregate-4",
           "aggregate-5",
           "aggregate-6",
           "aggregate-7",
           "aggregate-8",
           "aggregate-9"
         ]}
      )
    end
  end
end
