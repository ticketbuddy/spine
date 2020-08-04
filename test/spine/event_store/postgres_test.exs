defmodule Spine.EventStore.PostgresTest do
  use ExUnit.Case
  use Test.Support.Helper, repo: Test.Support.Repo

  defmodule PostgresTestDb do
    use Spine.EventStore.Postgres, repo: Test.Support.Repo
  end

  describe "committing events" do
    test "commits a single event" do
      event = %TestApp.Incremented{}
      cursor = {"aggregate-12345", 0}

      assert :ok == PostgresTestDb.commit(event, cursor)
    end

    test "commits multiple single events" do
      events = [%TestApp.Incremented{}, %TestApp.Incremented{}]
      cursor = {"aggregate-12345", 0}

      assert :ok == PostgresTestDb.commit(events, cursor)
    end

    test "when cursor points to an already written event" do
      events = [%TestApp.Incremented{}, %TestApp.Incremented{}]
      cursor_one = {"aggregate-12345", 0}
      cursor_two = {"aggregate-12345", 1}

      assert :ok == PostgresTestDb.commit(events, cursor_one)
      assert :error == PostgresTestDb.commit(events, cursor_two)
    end
  end

  describe "fetches events" do
    setup do
      PostgresTestDb.commit(%TestApp.Incremented{count: 5}, {"aggregate-12345", 0})
      PostgresTestDb.commit(%TestApp.Incremented{count: 10}, {"aggregate-12345", 1})
      PostgresTestDb.commit(%TestApp.Incremented{count: 15}, {"aggregate-12345", 2})

      PostgresTestDb.commit(%TestApp.Incremented{count: 20}, {"aggregate-6789", 0})
      PostgresTestDb.commit(%TestApp.Incremented{count: 25}, {"aggregate-6789", 1})
      PostgresTestDb.commit(%TestApp.Incremented{count: 30}, {"aggregate-6789", 2})

      :ok
    end

    test "fetches all events" do
      assert [
               # seeded event
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

    test "when individual event is not found" do
      assert nil == PostgresTestDb.event(-50)
    end
  end
end
