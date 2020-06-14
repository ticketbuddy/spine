defmodule SpineTest do
  use ExUnit.Case

  setup do
    {:ok, _pid} = Spine.BusDb.EphemeralDb.start_link([])

    {:ok, _pid} = Spine.EventStore.EphemeralDb.start_link([])

    :ok
  end

  defmodule MyApp do
    use Spine, event_store: Spine.EventStore.EphemeralDb, bus: Spine.BusDb.EphemeralDb
  end

  describe "Integration" do
    test "event store and bus" do
      listener = "listener-one"
      cursor = {"counter-1", 0}
      events = [5, 21, 32]

      MyApp.commit(events, cursor)
      MyApp.subscribe("listener-one")

      listener_cursor = MyApp.cursor(listener)

      assert {"counter-1", 5} == MyApp.event(listener_cursor)

      MyApp.completed(listener, listener_cursor)

      listener_cursor = MyApp.cursor(listener)

      assert {"counter-1", 21} == MyApp.event(listener_cursor)
    end
  end
end
