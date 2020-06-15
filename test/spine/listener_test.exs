defmodule Spine.ListenerTest do
  use ExUnit.Case

  setup do
    {:ok, _event_store} = Spine.EventStore.EphemeralDb.start_link([])
    {:ok, _bus_db} = Spine.BusDb.EphemeralDb.start_link([])

    %{
      config: %{
        bus_db: Spine.BusDb.EphemeralDb,
        event_store: Spine.EventStore.EphemeralDb,
        channel: "listener-one"
      }
    }
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

  describe "processing an event" do
    test "when event is successfully handled by callback", %{
      config: config
    } do
      config = Map.put(config, :callback, Callback)
      {:ok, listener} = Spine.Listener.start_link(config)

      event = {:an_event, self()}
      Spine.EventStore.EphemeralDb.commit([event], {"aggregate-one", 0})

      event_number = 0
      GenServer.cast(listener, {:process, event_number})

      assert_receive(:handled_an_event)

      assert %{"listener-one" => 1} == Spine.BusDb.EphemeralDb.subscriptions()
    end

    test "when event is not handled successfully by callback", %{config: config} do
      config = Map.put(config, :callback, Callback)
      {:ok, listener} = Spine.Listener.start_link(config)

      event = {:event_for_failed_callback, self()}
      Spine.EventStore.EphemeralDb.commit([event], {"aggregate-one", 0})

      event_number = 0
      GenServer.cast(listener, {:process, event_number})

      assert_receive(:event_for_failed_callback)

      assert %{"listener-one" => 0} == Spine.BusDb.EphemeralDb.subscriptions()
    end
  end
end
