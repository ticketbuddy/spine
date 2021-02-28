defmodule Spine.BusDb.PostgresTest do
  use ExUnit.Case
  use Test.Support.Mox
  use Test.Support.Helper, repo: Test.Support.Repo

  @start_listening_from 1

  defmodule PostgresTestDb do
    use Spine.BusDb.Postgres, repo: Test.Support.Repo, notifier: ListenerNotifierMock
  end

  setup do
    ListenerNotifierMock
    |> stub(:broadcast, fn {:listener_completed_event, _channel, _variant, _event_number} ->
      :ok
    end)

    :ok
  end

  test "subscribes listener to a channel" do
    channel = "channel-one"
    variant = "aggregate-one"

    assert {:ok, 1} = PostgresTestDb.subscribe(channel, variant, @start_listening_from)
  end

  test "returns cursor if subscription already created" do
    channel = "channel-one"
    variant = "aggregate-one"

    {:ok, 1} = PostgresTestDb.subscribe(channel, variant, @start_listening_from)

    :ok = PostgresTestDb.completed(channel, variant, 1)
    :ok = PostgresTestDb.completed(channel, variant, 2)

    assert {:ok, 3} = PostgresTestDb.subscribe(channel, variant, @start_listening_from)
  end

  describe "retrieves subscriptions" do
    test "for a single channel with multiple variants" do
      channel = "channel-one"
      variant_one = "aggregate-one"
      variant_two = "aggregate-two"
      variant_three = "aggregate-three"
      variant_four = "aggregate-four"

      PostgresTestDb.subscribe(channel, variant_one, @start_listening_from)
      PostgresTestDb.subscribe(channel, variant_two, @start_listening_from)
      PostgresTestDb.subscribe(channel, variant_three, @start_listening_from)
      PostgresTestDb.subscribe(channel, variant_four, @start_listening_from)

      assert %{
               "channel-one" => 1
             } == PostgresTestDb.subscriptions()
    end

    test "for multiple channels with multiple variants" do
      channel_one = "channel-one"
      channel_two = "channel-two"

      variant_one = "aggregate-one"
      variant_two = "aggregate-two"
      variant_three = "aggregate-three"
      variant_four = "aggregate-four"

      for channel <- [channel_one, channel_two] do
        PostgresTestDb.subscribe(channel, variant_one, @start_listening_from)
        PostgresTestDb.subscribe(channel, variant_two, @start_listening_from)
        PostgresTestDb.subscribe(channel, variant_three, @start_listening_from)
        PostgresTestDb.subscribe(channel, variant_four, @start_listening_from)
      end

      PostgresTestDb.completed(channel_one, variant_two, 7)
      PostgresTestDb.completed(channel_one, variant_three, 9)

      PostgresTestDb.completed(channel_two, variant_three, 2)
      PostgresTestDb.completed(channel_two, variant_four, 5)

      assert %{
               "channel-one" => 10,
               "channel-two" => 6
             } == PostgresTestDb.subscriptions()
    end
  end

  test "get cursor for the channel" do
    channel = "channel-one"
    variant = "aggregate-one"

    PostgresTestDb.subscribe(channel, variant, @start_listening_from)

    assert 1 == PostgresTestDb.cursor(channel, variant)
  end

  describe "when an event is completed" do
    test "increments cursor when :completed message received for correct cursor" do
      channel = "channel-one"
      variant = "aggregate-one"

      PostgresTestDb.subscribe(channel, variant, @start_listening_from)

      assert :ok == PostgresTestDb.completed(channel, variant, 0)

      expected_next_cursor = 1

      assert %{
               "channel-one" => expected_next_cursor
             } == PostgresTestDb.subscriptions()
    end

    test "does increment if completed cursor is greater than current cursor" do
      channel = "channel-one"
      variant = "aggregate-one"

      PostgresTestDb.subscribe(channel, variant, @start_listening_from)

      assert :ok == PostgresTestDb.completed(channel, variant, 5)

      expected_next_cursor = 6

      assert %{
               channel => expected_next_cursor
             } == PostgresTestDb.subscriptions()
    end

    test "does not increment cursor when :completed message received for a previous cursor" do
      channel = "channel-one"
      variant = "aggregate-one"

      PostgresTestDb.subscribe(channel, variant, @start_listening_from)

      assert :ok == PostgresTestDb.completed(channel, variant, -1)

      expected_next_cursor = 1

      assert %{
               "channel-one" => expected_next_cursor
             } == PostgresTestDb.subscriptions()
    end
  end
end
