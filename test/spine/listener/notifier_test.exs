defmodule Spine.Listener.NotifierTest do
  use ExUnit.Case, async: false
  use Test.Support.Mox

  alias Phoenix.PubSub

  @topic "new_event_topic"
  @listener_channel "notifier-test-channel"

  defmodule MyApp do
    use Spine, event_store: EventStoreMock, bus: BusDbMock
  end

  defmodule MyPubSub do
    use Spine.Listener.Notifier.PubSub, pubsub: :notifier_pubsub, topic: "new_event_topic"
  end

  setup do
    opts = [strategy: :one_for_one, name: NotifierTestSupervisor]

    children = [{Phoenix.PubSub, name: :notifier_pubsub}]

    {:ok, _pid} = Supervisor.start_link(children, opts)

    BusDbMock
    |> expect(:subscribe, fn @listener_channel -> {:ok, 1} end)

    config = %{
      channel: @listener_channel,
      callback: nil,
      spine: MyApp,
      notifier: MyPubSub
    }

    expect(EventStoreMock, :next_event, fn 1 -> {:ok, :no_next_event} end)

    assert {:ok, pid} = Spine.Listener.start_link(config)

    :ok
  end

  describe "a phoenix pubsub implementation" do
    test "notifies listener of new events" do
      expect(EventStoreMock, :next_event, fn 1 -> {:ok, :no_next_event} end)

      MyPubSub.broadcast(:process)

      :timer.sleep(200)
    end
  end
end