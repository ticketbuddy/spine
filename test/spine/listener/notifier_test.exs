defmodule Spine.Listener.NotifierTest do
  use ExUnit.Case, async: false
  use Test.Support.Mox

  @listener_channel "notifier-test-channel"

  defmodule MyApp do
    use Spine, event_store: EventStoreMock, bus: BusDbMock
  end

  defmodule MyPubSub do
    use Spine.Listener.Notifier.PubSub, pubsub: :notifier_pubsub, topic: "new_event_topic"
  end

  defmodule ListenerCallback do
    use Spine.Listener.Callback, channel: "notifier-test-channel"

    @impl true
    def handle_event(_event, _meta), do: :ok
  end

  setup do
    opts = [strategy: :one_for_one, name: NotifierTestSupervisor]

    children = [{Phoenix.PubSub, name: :notifier_pubsub}]

    {:ok, _pid} = Supervisor.start_link(children, opts)

    start_supervised!(
      {DynamicSupervisor, strategy: :one_for_one, name: MyApp.ListenerDynamicSupervisor}
    )

    BusDbMock
    |> expect(:subscribe, fn @listener_channel, "single", 1 -> {:ok, 1} end)

    BusDbMock
    |> expect(:all_variants, fn _callback, channel: "notifier-test-channel" ->
      {:ok, :ok}
    end)

    config = %{
      callback: ListenerCallback,
      spine: MyApp,
      notifier: MyPubSub,
      listener_supervisor: MyApp.ListenerDynamicSupervisor
    }

    assert {:ok, pid} = Spine.Listener.start_link(config)
    assert is_pid(pid)

    :ok
  end

  describe "a phoenix pubsub implementation" do
    test "notifies listener of new events" do
      expect(EventStoreMock, :next_event, fn 1, [] -> {:ok, :no_next_event} end)

      MyPubSub.broadcast({:process, "aggregate-one"})

      :timer.sleep(200)
    end
  end
end
