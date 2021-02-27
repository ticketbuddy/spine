defmodule SpineTest do
  use ExUnit.Case
  use Test.Support.Mox

  use Test.Support.Helper, repo: Test.Support.Repo

  defmodule EventCommittedNotifier do
    use Spine.Listener.Notifier.PubSub,
      pubsub: :event_committed_notifier,
      topic: "event_committed_notifier"
  end

  defmodule BusProgressNotifier do
    use Spine.Listener.Notifier.PubSub,
      pubsub: :bus_progress_notifier,
      topic: "bus_progress_notifier"
  end

  defmodule MyApp do
    defmodule MyEventStore do
      use Spine.EventStore.Postgres, repo: Test.Support.Repo, notifier: EventCommittedNotifier
    end

    defmodule MyEventBus do
      use Spine.BusDb.Postgres, repo: Test.Support.Repo, notifier: BusProgressNotifier
    end

    use Spine, event_store: MyEventStore, bus: MyEventBus

    defmodule Handler do
      def execute(_current_state, %{amount: amount}) when amount < 0,
        do: {:error, :amount_must_be_positive}

      def execute(nil, wish), do: {:ok, wish.amount}
      def execute(_current_state, wish), do: {:ok, wish.amount}

      def next_state(nil, event), do: event
      def next_state(current_state, event), do: current_state + event
    end

    defmodule ListenerCallback do
      use Spine.Listener.Callback, channel: "some-channel"

      @impl true
      def handle_event(_event, _meta), do: :ok
    end
  end

  defmodule EventCatalog do
    import Spine.Wish, only: [defwish: 3]

    defwish(Inc, [:counter_id, amount: 1], to: MyApp.Handler)
  end

  describe "Integration" do
    setup do
      Mox.stub(ListenerNotifierMock, :broadcast, fn {:process, _aggregate_id} -> :ok end)

      start_supervised!({Phoenix.PubSub, name: :bus_progress_notifier}, id: :bus_progress_notifier)

      start_supervised!({Phoenix.PubSub, name: :event_committed_notifier},
        id: :event_committed_notifier
      )

      start_supervised!(
        {DynamicSupervisor, strategy: :one_for_one, name: MyApp.ListenerDynamicSupervisor}
      )

      start_supervised!(
        {Spine.Listener,
         %{
           notifier: EventCommittedNotifier,
           spine: MyApp,
           callback: MyApp.ListenerCallback,
           channel: "some-channel",
           listener_supervisor: MyApp.ListenerDynamicSupervisor
         }}
      )

      :ok
    end

    test "handling a wish that is allowed" do
      wish = %EventCatalog.Inc{counter_id: "counter-1"}

      assert :ok == MyApp.handle(wish)
    end

    test "handling a wish that requires strong consistency" do
      wish = %EventCatalog.Inc{counter_id: "counter-1"}

      assert :ok = MyApp.handle(wish, strong_consistency: [MyApp.ListenerCallback])
    end

    test "handling a wish that requires strong consistency times out" do
      wish = %EventCatalog.Inc{counter_id: "counter-1"}

      assert {:timeout, event_number} =
               MyApp.handle(wish,
                 strong_consistency: [MyApp.ListenerCallback],
                 consistency_timeout: 0
               )

      assert is_integer(event_number)
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
