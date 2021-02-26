defmodule Spine.ConsistencyE2eTest do
  use ExUnit.Case
  use Test.Support.Mox

  use Test.Support.Helper, repo: Test.Support.Repo

  @channel "a-channel-to-be-strongly-consistent-with"

  defmodule EventCommittedNotifier do
    use Spine.Listener.Notifier.PubSub,
      pubsub: :event_committed_notifier_strong_consistency,
      topic: "event_committed_notifier_strong_consistency"
  end

  defmodule BusProgressNotifier do
    use Spine.Listener.Notifier.PubSub,
      pubsub: :bus_progress_notifier_strong_consistent,
      topic: "bus_progress_notifier_strong_consistent"
  end

  defmodule MyStronglyConsistentApp do
    defmodule MyEventStore do
      use Spine.EventStore.Postgres, repo: Test.Support.Repo, notifier: EventCommittedNotifier
    end

    defmodule MyEventBus do
      use Spine.BusDb.Postgres, repo: Test.Support.Repo, notifier: BusProgressNotifier
    end

    use Spine, event_store: MyEventStore, bus: MyEventBus

    defmodule Handler do
      def execute(_current_state, wish),
        do: {:ok, %{time: wish.time_ms, reply_pid: wish.reply_pid}}

      def next_state(_current_state, _event), do: :nothing
    end

    defmodule ListenerCallback do
      use Spine.Listener.Callback, channel: "a-channel-to-be-strongly-consistent-with"

      @impl true
      def handle_event(%{time: sleep_for, reply_pid: pid}, _meta) do
        :timer.sleep(sleep_for)
        send(pid, {:strong_consistency_handle_event, DateTime.utc_now()})

        :ok
      end

      @impl true
      def handle_event(_event, _meta), do: :ok
    end
  end

  defmodule EventCatalog do
    import Spine.Wish, only: [defwish: 3]

    defwish(Sleep, [:timer, :reply_pid, time_ms: 1], to: MyStronglyConsistentApp.Handler)
  end

  describe "Consistency integration" do
    setup do
      start_supervised!({Phoenix.PubSub, name: :bus_progress_notifier_strong_consistent},
        id: :bus_progress_notifier_strong_consistent
      )

      start_supervised!({Phoenix.PubSub, name: :event_committed_notifier_strong_consistency},
        id: :event_committed_notifier_strong_consistency
      )

      start_supervised!(
        {DynamicSupervisor,
         strategy: :one_for_one, name: MyStronglyConsistentApp.ListenerDynamicSupervisor}
      )

      start_supervised!(
        {Spine.Listener,
         %{
           listener_supervisor: MyStronglyConsistentApp.ListenerDynamicSupervisor,
           notifier: EventCommittedNotifier,
           spine: MyStronglyConsistentApp,
           callback: MyStronglyConsistentApp.ListenerCallback,
           channel: @channel
         }}
      )

      :ok
    end

    test "eventual consistency, receives result before listener has completed" do
      wish = %EventCatalog.Sleep{timer: "time-one", time_ms: 700, reply_pid: self()}

      result = MyStronglyConsistentApp.handle(wish)
      result_received_at = DateTime.utc_now()

      listener_completed_at =
        receive do
          {:strong_consistency_handle_event, completed_at} -> completed_at
        end

      assert :ok == result
      assert :lt == DateTime.compare(result_received_at, listener_completed_at)
    end

    test "strong consistency, receives result after listener has completed" do
      wish = %EventCatalog.Sleep{timer: "time-one", time_ms: 700, reply_pid: self()}

      result =
        MyStronglyConsistentApp.handle(wish,
          strong_consistency: [MyStronglyConsistentApp.ListenerCallback]
        )

      result_received_at = DateTime.utc_now()

      listener_completed_at =
        receive do
          {:strong_consistency_handle_event, completed_at} -> completed_at
        end

      assert :ok == result
      assert :gt == DateTime.compare(result_received_at, listener_completed_at)
    end

    test "strong consistency, when listener handler times out" do
      wish = %EventCatalog.Sleep{timer: "time-one", time_ms: 700, reply_pid: self()}

      result =
        MyStronglyConsistentApp.handle(wish,
          strong_consistency: [MyStronglyConsistentApp.ListenerCallback],
          consistency_timeout: 500
        )

      result_received_at = DateTime.utc_now()

      listener_completed_at =
        receive do
          {:strong_consistency_handle_event, completed_at} -> completed_at
        end

      assert {:timeout, event_number} = result
      assert is_integer(event_number)
      assert :lt == DateTime.compare(result_received_at, listener_completed_at)
    end
  end
end
