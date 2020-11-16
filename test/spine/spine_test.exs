defmodule SpineTest do
  use ExUnit.Case
  use Test.Support.Mox

  use Test.Support.Helper, repo: Test.Support.Repo

  defmodule MyApp do
    defmodule MyEventStore do
      use Spine.EventStore.Postgres, repo: Test.Support.Repo, notifier: ListenerNotifierMock
    end

    defmodule MyEventBus do
      use Spine.BusDb.Postgres, repo: Test.Support.Repo
    end

    use Spine, event_store: MyEventStore, bus: MyEventBus

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

  setup do
    Mox.stub(ListenerNotifierMock, :broadcast, fn :process -> :ok end)

    :ok
  end

  describe "Integration" do
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
