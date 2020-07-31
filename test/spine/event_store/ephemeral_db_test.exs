defmodule Spine.EventStore.EphemeralDbTest do
  use ExUnit.Case
  alias Spine.EventStore.EphemeralDb

  setup do
    {:ok, _pid} = Spine.EventStore.EphemeralDb.start_link([])

    :ok
  end

  describe "commit events" do
    test "has correct key" do
      cursor = {"counter-1", 0}

      assert :ok = EphemeralDb.commit([5, 6, 7, 8], cursor)
    end

    test "has incorrect key" do
      cursor = {"counter-1", 1}

      assert :incorrect_key = EphemeralDb.commit([5, 6, 7, 8], cursor)
    end

    test "aggregate key is aggregate independant" do
      cursor_one = {"counter-1", 0}
      cursor_two = {"counter-2", 0}

      assert :ok = EphemeralDb.commit([5, 6, 7, 8], cursor_one)
      assert :ok = EphemeralDb.commit([:x, :y, :z], cursor_two)

      assert :incorrect_key = EphemeralDb.commit([:add_again], cursor_one)
      assert :incorrect_key = EphemeralDb.commit([:add_again], cursor_two)
    end

    test "prevents a key which is over the existing aggregate count" do
      cursor = {"counter-2", 5}

      assert :incorrect_key = EphemeralDb.commit([5, 6, 7, 8], cursor)
    end
  end

  describe "seeds an event" do
    test "adds an event" do
      aggregate_id = "agg-12345"

      assert :ok = EphemeralDb.seed(:an_event, aggregate_id)
      assert :ok = EphemeralDb.seed(:a_second_event, aggregate_id)

      assert [{"agg-12345", :an_event}, {"agg-12345", :a_second_event}] ==
               EphemeralDb.all_events()
    end
  end

  test "keeps order when new events are fetched" do
    :ok = EphemeralDb.commit([5], {"counter-1", 0})
    :ok = EphemeralDb.commit([:a], {"counter-1", 1})

    assert [{"counter-1", 5}, {"counter-1", :a}] == EphemeralDb.all_events()
  end

  test "can retrieve individual events" do
    :ok = EphemeralDb.commit([:a, :b, :c, :d], {"counter-1", 0})

    assert {"counter-1", :a} == EphemeralDb.event(0)
    assert {"counter-1", :b} == EphemeralDb.event(1)
    assert {"counter-1", :c} == EphemeralDb.event(2)
    assert {"counter-1", :d} == EphemeralDb.event(3)
  end

  test "retrieves events" do
    cursor = {"counter-1", 0}

    EphemeralDb.commit([:a, :b, :c, :d], cursor)

    assert [{"counter-1", :a}, {"counter-1", :b}, {"counter-1", :c}, {"counter-1", :d}] ==
             EphemeralDb.all_events()
  end

  test "retrieves events for given aggregate" do
    EphemeralDb.commit([:a, :b, :c, :d], {"counter-1", 0})
    EphemeralDb.commit([9, 7, 5, 3], {"counter-2", 0})

    assert [{"counter-1", :a}, {"counter-1", :b}, {"counter-1", :c}, {"counter-1", :d}] ==
             EphemeralDb.aggregate_events("counter-1")
  end
end
