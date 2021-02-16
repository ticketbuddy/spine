defmodule Spine.BusDb.PostgresTest do
  use ExUnit.Case
  use Test.Support.Helper, repo: Test.Support.Repo

  @start_listening_from 1

  defmodule PostgresTestDb do
    use Spine.BusDb.Postgres, repo: Test.Support.Repo
  end

  test "subscribes listener to a channel" do
    assert {:ok, 1} = PostgresTestDb.subscribe("channel-one", @start_listening_from)
  end

  test "returns cursor if subscription already created" do
    {:ok, 1} = PostgresTestDb.subscribe("channel-one", @start_listening_from)

    :ok = PostgresTestDb.completed("channel-one", 1)
    :ok = PostgresTestDb.completed("channel-one", 2)

    assert {:ok, 3} = PostgresTestDb.subscribe("channel-one", @start_listening_from)
  end

  test "retrieves subscriptions" do
    PostgresTestDb.subscribe("channel-one", @start_listening_from)

    assert %{
             "channel-one" => 1
           } == PostgresTestDb.subscriptions()
  end

  test "get cursor for the channel" do
    PostgresTestDb.subscribe("channel-one", @start_listening_from)

    assert 1 == PostgresTestDb.cursor("channel-one")
  end

  describe "when an event is completed" do
    test "increments cursor when :completed message received for correct cursor" do
      PostgresTestDb.subscribe("channel-one", @start_listening_from)

      assert :ok == PostgresTestDb.completed("channel-one", 0)

      expected_next_cursor = 1

      assert %{
               "channel-one" => expected_next_cursor
             } == PostgresTestDb.subscriptions()
    end

    test "does increment if completed cursor is greater than current cursor" do
      PostgresTestDb.subscribe("channel-one", @start_listening_from)

      assert :ok == PostgresTestDb.completed("channel-one", 5)

      expected_next_cursor = 6

      assert %{
               "channel-one" => expected_next_cursor
             } == PostgresTestDb.subscriptions()
    end

    test "does not increment cursor when :completed message received for a previous cursor" do
      PostgresTestDb.subscribe("channel-one", @start_listening_from)

      assert :ok == PostgresTestDb.completed("channel-one", -1)

      expected_next_cursor = 1

      assert %{
               "channel-one" => expected_next_cursor
             } == PostgresTestDb.subscriptions()
    end
  end
end
