defmodule Spine.Listener.NotifierTest do
  use ExUnit.Case, async: false
  use Test.Support.Mox

  defmodule MyPubSub do
    use Spine.Listener.Notifier.PubSub, pubsub: :a_notifier, topic: "a_notifier"
  end

  setup do
    ExUnit.Callbacks.start_supervised!({Phoenix.PubSub, name: :a_notifier}, id: :a_notifier)

    :ok
  end

  describe "a phoenix pubsub implementation" do
    test "notifies listener of new events" do
      MyPubSub.subscribe()

      MyPubSub.broadcast(:send_this)

      assert_receive(:send_this)
    end
  end
end
