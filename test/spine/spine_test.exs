defmodule SpineTest do
  use ExUnit.Case

  setup do
    {:ok, _pid} = Spine.BusDb.EphemeralDb.start_link([])

    {:ok, _pid} = Spine.EventStore.EphemeralDb.start_link([])

    :ok
  end

  defmodule MyApp do
    use Spine, event_store: Spine.EventStore.EphemeralDb, bus: Spine.BusDb.EphemeralDb

    defmodule Handler do
      def execute(_current_state, %{amount: amount}) when amount < 0,
        do: {:error, :amount_must_be_positive}

      def execute(nil, wish), do: {:ok, wish.amount}
      def execute(current_state, wish), do: {:ok, wish.amount}

      def next_state(nil, event), do: event
      def next_state(current_state, event), do: current_state + event
    end
  end

  defmodule EventCatalog do
    import Spine.Wish, only: [defwish: 3]

    defwish(Inc, [:counter_id, amount: 1], to: MyApp.Handler)
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

    test "handling a wish that is allowed" do
      wish = %EventCatalog.Inc{counter_id: "counter-1"}

      assert :ok == MyApp.handle(wish)
    end

    test "handling a wish, that is not allowed" do
      wish = %EventCatalog.Inc{counter_id: "counter-1", amount: -1}

      assert {:error, :amount_must_be_positive} == MyApp.handle(wish)
    end

    test "can read the state of an aggregate back" do
      MyApp.handle(%EventCatalog.Inc{counter_id: "counter-1", amount: 5})
      MyApp.handle(%EventCatalog.Inc{counter_id: "counter-1", amount: 15})

      assert 20 == MyApp.read("counter-1", MyApp.Handler)
    end
  end
end
