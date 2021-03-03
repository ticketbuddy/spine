defmodule Spine.EventStore.PostgresTest do
  use ExUnit.Case
  use Test.Support.Mox
  use Test.Support.Helper, repo: Test.Support.Repo

  defmodule PostgresTestDb do
    use Spine.EventStore.Postgres, repo: Test.Support.Repo, notifier: CommitNotifierMock
  end

  setup do
    Mox.stub(CommitNotifierMock, :broadcast, fn :process -> :ok end)

    :ok
  end

  describe "committing events" do
    test "commits a single event" do
      event = %TestApp.Incremented{}
      cursor = {"aggregate-12345", 1}

      assert {:ok, event_number} = PostgresTestDb.commit(event, cursor, [])
      assert is_integer(event_number)
    end

    test "broadcasts message after a commit has been processed" do
      Mox.expect(CommitNotifierMock, :broadcast, fn :process -> :ok end)

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
               PostgresTestDb.next_event(event_number)
    end

    test "fetches the next event, when there is a gap" do
      event_number = 3

      assert {:ok, %TestApp.Incremented{}, %{event_number: 4, inserted_at: %DateTime{}}} =
               PostgresTestDb.next_event(event_number)
    end

    test "when there is not a next_event" do
      event_number = 6_234

      assert {:ok, :no_next_event} == PostgresTestDb.next_event(event_number)
    end

    test "when individual event is not found" do
      assert nil == PostgresTestDb.event(-50)
    end

    test "fetches next events orderded by aggregate id and event number" do
      {:ok, event_number} =
        PostgresTestDb.commit(%TestApp.Incremented{count: 7}, {"aggregate-a", 1}, [])

      {:ok, event_number_two} =
        PostgresTestDb.commit(%TestApp.Incremented{count: 7}, {"aggregate-b", 1}, [])

      {:ok, event_number_three} =
        PostgresTestDb.commit(%TestApp.Incremented{count: 7}, {"aggregate-a", 2}, [])

      {:ok, event_number_four} =
        PostgresTestDb.commit(%TestApp.Incremented{count: 7}, {"aggregate-b", 2}, [])

      assert events =
               [
                 {%TestApp.Incremented{},
                  %{
                    aggregate_id: "aggregate-a",
                    event_number: ^event_number
                  }},
                 {%TestApp.Incremented{},
                  %{
                    aggregate_id: "aggregate-a",
                    event_number: ^event_number_three
                  }},
                 {%TestApp.Incremented{},
                  %{
                    aggregate_id: "aggregate-b",
                    event_number: ^event_number_two
                  }},
                 {%TestApp.Incremented{},
                  %{
                    aggregate_id: "aggregate-b",
                    event_number: ^event_number_four
                  }}
               ] = PostgresTestDb.next_events(event_number)
    end
  end
end
