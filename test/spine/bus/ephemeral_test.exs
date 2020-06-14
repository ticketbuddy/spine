defmodule Spine.Bus.EphemeralTest do
  use ExUnit.Case
  alias Spine.Bus.Ephemeral

  setup do
    {:ok, _pid} = Ephemeral.start_link([])

    :ok
  end

  test "subscribes listener to a channel" do
    assert :ok = Ephemeral.subscribe("channel-one")
  end

  test "retrieves subscriptions" do
    Ephemeral.subscribe("channel-one")

    assert %{
             "channel-one" => {self(), 0}
           } == Ephemeral.subscriptions()
  end

  test "get cursor for the channel" do
    Ephemeral.subscribe("channel-one")

    assert 0 == Ephemeral.cursor("channel-one")
  end

  describe "when an event is completed" do
    test "increments cursor when :completed message received for correct cursor" do
      Ephemeral.subscribe("channel-one")

      assert :ok == Ephemeral.completed("channel-one", 0)

      assert %{
               "channel-one" => {self(), 1}
             } == Ephemeral.subscriptions()
    end

    test "does not increment cursor when :completed message received for incorrect cursor" do
      Ephemeral.subscribe("channel-one")

      assert :ok == Ephemeral.completed("channel-one", 1)

      assert %{
               "channel-one" => {self(), 0}
             } == Ephemeral.subscriptions()
    end
  end
end
