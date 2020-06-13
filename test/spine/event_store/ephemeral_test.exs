defmodule Spine.EventStore.EphemeralTest do
  use ExUnit.Case
  alias Spine.EventStore.Ephemeral

  setup do
    {:ok, pid} = Spine.EventStore.Ephemeral.start_link([])

    :ok
  end

  describe "commit events" do
    test "has correct key" do
      cursor = {"counter-1", 0}

      assert :ok = Ephemeral.commit([5, 6, 7, 8], cursor)
    end

    test "has incorrect key" do
      cursor = {"counter-1", 1}

      assert :incorrect_key = Ephemeral.commit([5, 6, 7, 8], cursor)
    end

    test "aggregate key is aggregate independant" do
      cursor_one = {"counter-1", 0}
      cursor_two = {"counter-2", 0}

      assert :ok = Ephemeral.commit([5, 6, 7, 8], cursor_one)
      assert :ok = Ephemeral.commit([:x, :y, :z], cursor_two)

      assert :incorrect_key = Ephemeral.commit([:add_again], cursor_one)
      assert :incorrect_key = Ephemeral.commit([:add_again], cursor_two)
    end

    test "prevents a key which is over the existing aggregate count" do
      cursor = {"counter-2", 5}

      assert :incorrect_key = Ephemeral.commit([5, 6, 7, 8], cursor)
    end
  end

  test "retrieves events" do
    cursor = {"counter-1", 0}

    Ephemeral.commit([:a, :b, :c, :d], cursor)

    assert [{"counter-1", :a}, {"counter-1", :b}, {"counter-1", :c}, {"counter-1", :d}] ==
             Ephemeral.all_events()
  end

  test "retrieves events for given aggregate" do
    Ephemeral.commit([:a, :b, :c, :d], {"counter-1", 0})
    Ephemeral.commit([9, 7, 5, 3], {"counter-2", 0})

    assert [{"counter-1", :a}, {"counter-1", :b}, {"counter-1", :c}, {"counter-1", :d}] ==
             Ephemeral.aggregate_events("counter-1")
  end
end
