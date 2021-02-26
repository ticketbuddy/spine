defmodule Spine.StrongConsistencyTest do
  use ExUnit.Case
  use Test.Support.Mox

  use Test.Support.Helper, repo: Test.Support.Repo

  @channel "a-channel-to-be-strongly-consistent-with"

  defmodule MyStronglyConsistentApp do
    defmodule MyEventStore do
      use Spine.EventStore.Postgres, repo: Test.Support.Repo, notifier: ListenerNotifierMock
    end

    defmodule MyEventBus do
      use Spine.BusDb.Postgres, repo: Test.Support.Repo
    end

    use Spine, event_store: MyEventStore, bus: MyEventBus

    defmodule Handler do
      def execute(_current_state, wish),
        do: {:ok, %{time: wish.time_ms, reply_pid: wish.reply_pid}}

      def next_state(_current_state, _event), do: :nothing
    end

    defmodule ListenerCallback do
      def handle_event(%{time: sleep_for, reply_pid: pid}, _meta) do
        :timer.sleep(sleep_for)
        send(pid, {:strong_consistency_handle_event, DateTime.utc_now()})

        :ok
      end

      def handle_event(_event, _meta), do: :ok
    end
  end

  defmodule EventCatalog do
    import Spine.Wish, only: [defwish: 3]

    defwish(Sleep, [:timer, :reply_pid, time_ms: 1], to: MyStronglyConsistentApp.Handler)
  end

  defmodule BusProgressNotifier do
    use Spine.Listener.Notifier.PubSub,
      pubsub: :bus_progress_notifier_strong_consistent,
      topic: "bus_progress_notifier_strong_consistent"
  end

  describe "Strong consistency integration" do
    setup do
      Mox.stub(ListenerNotifierMock, :broadcast, fn :process -> :ok end)

      Spine.Consistency.start_link(%{
        notifier: BusProgressNotifier,
        spine: MyStronglyConsistentApp
      })

      start_supervised!({Phoenix.PubSub, name: :bus_progress_notifier_strong_consistent})

      start_supervised!(
        {Spine.Listener,
         %{
           notifier: BusProgressNotifier,
           spine: MyStronglyConsistentApp,
           callback: MyStronglyConsistentApp.ListenerCallback,
           channel: @channel
         }}
      )

      :ok
    end

    test "receives message from listener before result is returned" do
      wish = %EventCatalog.Sleep{timer: "time-one", time_ms: 3_000, reply_pid: self()}

      result = MyStronglyConsistentApp.handle(wish, strong_consistency: [@channel])
      result_received_at = DateTime.utc_now()

      listner_completed_at =
        receive do
          {:strong_consistency_handle_event, completed_at} -> completed_at
        end

      assert :gt == DateTime.compare(result_received_at, listner_completed_at)
    end
  end
end
