defmodule Spine.BusDb.PostgresTest do
  use ExUnit.Case
  use Test.Support.Helper, repo: Test.Support.Repo

  defmodule PostgresTestDb do
    use Spine.BusDb.Postgres, repo: Test.Support.Repo
  end

  test "subscribes listener to a channel" do
    assert {:ok, 1} = PostgresTestDb.subscribe("channel-one")
  end

  test "returns cursor if subscription already created" do
    {:ok, 1} = PostgresTestDb.subscribe("channel-one")

    :ok = PostgresTestDb.completed("channel-one", 1)

    assert {:ok, 2} = PostgresTestDb.subscribe("channel-one")
  end

  test "retrieves subscriptions" do
    PostgresTestDb.subscribe("channel-one")

    assert %{
             "channel-one" => 1
           } == PostgresTestDb.subscriptions()
  end

  test "get cursor for the channel" do
    PostgresTestDb.subscribe("channel-one")

    assert 1 == PostgresTestDb.cursor("channel-one")
  end

  describe "when an event is completed" do
    test "increments cursor when :completed message received for correct cursor" do
      PostgresTestDb.subscribe("channel-one")

      assert :ok == PostgresTestDb.completed("channel-one", 0)

      assert %{
               "channel-one" => 1
             } == PostgresTestDb.subscriptions()
    end

    test "does not increment cursor when :completed message received for incorrect cursor" do
      PostgresTestDb.subscribe("channel-one")

      assert :ok == PostgresTestDb.completed("channel-one", 2)

      assert %{
               "channel-one" => 1
             } == PostgresTestDb.subscriptions()
    end
  end
end
