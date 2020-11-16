defmodule Spine.Listener.Notifier.PubSubTest do
  use ExUnit.Case

  defmodule MyPubSub do
    use Spine.Listener.Notifier.PubSub, pubsub: :notifier_pubsub, topic: "pubsub_test_topic"
  end

  setup do
    opts = [strategy: :one_for_one, name: NotifierTestSupervisor]

    children = [{Phoenix.PubSub, name: :notifier_pubsub}]

    {:ok, _pid} = Supervisor.start_link(children, opts)

    :ok
  end

  test "subscribes and publishes to a topic" do
    MyPubSub.subscribe()

    MyPubSub.broadcast(:process)

    assert_receive(:process)
  end
end
