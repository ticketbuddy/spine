defmodule Spine.EventStore.PostgresTest do
  use ExUnit.Case
  use Test.Support.Helper, repo: Test.Support.Repo

  defmodule PostgresTestDb do
    use Spine.EventStore.Postgres, repo: Test.Support.Repo
  end

  describe "committing events" do
    test "commits a single event" do
      event = :an_event
      cursor = {"aggregate-12345", 0}

      assert :ok == PostgresTestDb.commit(event, cursor)
    end

    test "commits multiple single events" do
      events = [:an_event, :another_event]
      cursor = {"aggregate-12345", 0}

      assert :ok == PostgresTestDb.commit(events, cursor)
    end

    test "when cursor points to an already written event" do
      events = [:an_event, :another_event]
      cursor_one = {"aggregate-12345", 0}
      cursor_two = {"aggregate-12345", 1}

      assert :ok == PostgresTestDb.commit(events, cursor_one)
      assert :error == PostgresTestDb.commit(events, cursor_two)
    end
  end
end
