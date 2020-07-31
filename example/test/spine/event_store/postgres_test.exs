defmodule Spine.EventStore.PostgresTest do
  use ExUnit.Case
  use Test.Support.Helper, repo: Example.Repo

  describe "committing events" do
    test "a single event" do
      event = :an_event
      cursor = {"aggregate_id", 0}

      assert :ok == Example.commit(event, cursor)
    end

    test "multiple events" do
      events = [:an_event, :another_event]
      cursor = {"aggregate_id", 0}

      assert :ok == Example.commit(events, cursor)
    end

    test "rejects when cursor clashes with previous event" do
      event = :an_event
      cursor = {"aggregate_id", 0}

      assert :ok == Example.commit(event, cursor)
      assert :error == Example.commit(event, cursor)
    end
  end
end
