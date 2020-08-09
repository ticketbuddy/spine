defmodule Spine.ListenerTest do
  use ExUnit.Case

  defmodule AppsSpine do
    use Spine, event_store: Spine.EventStore.EphemeralDb, bus: Spine.BusDb.EphemeralDb
  end

  defmodule Callback do
    def handle_event({:an_event, pid}) do
      send(pid, :handled_an_event)

      :ok
    end

    def handle_event({:event_for_failed_callback, pid}) do
      send(pid, :event_for_failed_callback)

      :error
    end
  end

  setup do
    {:ok, _event_store} = Spine.EventStore.EphemeralDb.start_link([])
    {:ok, _bus_db} = Spine.BusDb.EphemeralDb.start_link([])

    %{
      config: %{
        channel: "listener-one",
        spine: AppsSpine
      }
    }
  end

  describe "processing an event" do
    test "when no events to process", %{config: config} do
      config = Map.put(config, :callback, Callback)

      {:ok, listener} = Spine.Listener.start_link(config)

      assert {0, config} == :sys.get_state({:global, "listener-one"})
    end

    test "when event is successfully handled by callback", %{
      config: config
    } do
      config = Map.put(config, :callback, Callback)
      {:ok, listener} = Spine.Listener.start_link(config)

      event = {:an_event, self()}
      Spine.EventStore.EphemeralDb.commit([event], {"aggregate-one", 0})

      assert_receive(:handled_an_event, 1_000)

      assert %{"listener-one" => 1} == Spine.BusDb.EphemeralDb.subscriptions()

      assert {1, config} == :sys.get_state(listener)
    end

    test "when event is not handled successfully by callback", %{config: config} do
      config = Map.put(config, :callback, Callback)
      {:ok, listener} = Spine.Listener.start_link(config)

      event = {:event_for_failed_callback, self()}
      Spine.EventStore.EphemeralDb.commit([event], {"aggregate-one", 0})

      assert_receive(:event_for_failed_callback, 1_000)

      assert %{"listener-one" => 0} == Spine.BusDb.EphemeralDb.subscriptions()

      assert {0, config} == :sys.get_state(listener)
    end
  end
end
