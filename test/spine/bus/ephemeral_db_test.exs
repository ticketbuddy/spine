defmodule Spine.Bus.EphemeralDbTest do
  use ExUnit.Case
  alias Spine.Bus.EphemeralDb

  setup do
    {:ok, _pid} = EphemeralDb.start_link([])

    :ok
  end

  test "subscribes listener to a channel" do
    assert :ok = EphemeralDb.subscribe("channel-one")
  end

  test "retrieves subscriptions" do
    EphemeralDb.subscribe("channel-one")

    assert %{
             "channel-one" => 0
           } == EphemeralDb.subscriptions()
  end

  test "get cursor for the channel" do
    EphemeralDb.subscribe("channel-one")

    assert 0 == EphemeralDb.cursor("channel-one")
  end

  describe "when an event is completed" do
    test "increments cursor when :completed message received for correct cursor" do
      EphemeralDb.subscribe("channel-one")

      assert :ok == EphemeralDb.completed("channel-one", 0)

      assert %{
               "channel-one" => 1
             } == EphemeralDb.subscriptions()
    end

    test "does not increment cursor when :completed message received for incorrect cursor" do
      EphemeralDb.subscribe("channel-one")

      assert :ok == EphemeralDb.completed("channel-one", 1)

      assert %{
               "channel-one" => 0
             } == EphemeralDb.subscriptions()
    end
  end
end
