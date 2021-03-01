defmodule Spine.Consistency.UtilsTest do
  use ExUnit.Case
  alias Spine.Consistency.Utils

  test "when all subscriptions are consistent" do
    event_number = 449

    subscriptions = %{
      "channel-one" => 450,
      "channel-two" => 450,
      "channel-three" => 450
    }

    channels = ["channel-one", "channel-two", "channel-three"]

    assert Utils.is_consistent?(subscriptions, channels, event_number)
  end

  test "allows subscriptions to not be consistent, if not specified" do
    event_number = 449

    subscriptions = %{
      "channel-one" => 450,
      "channel-two" => 450,
      "channel-three" => 400
    }

    channels = ["channel-one", "channel-two"]

    assert Utils.is_consistent?(subscriptions, channels, event_number)
  end

  test "rejects when channel is not looking to complete the event after the desired event_number" do
    event_number = 449

    subscriptions = %{
      "channel-one" => 450,
      "channel-two" => 449,
      "channel-three" => 400
    }

    channels = ["channel-one", "channel-two"]

    refute Utils.is_consistent?(subscriptions, channels, event_number)
  end

  test "raises exception when a channel that isn't in the subscription list is provided" do
    event_number = 450

    subscriptions = %{
      "channel-one" => 450,
      "channel-two" => 449,
      "channel-three" => 400
    }

    assert_raise RuntimeError, fn ->
      Utils.is_consistent?(subscriptions, ["channel-one", "channel-eight"], event_number)
    end

    assert_raise RuntimeError, fn ->
      Utils.is_consistent?(subscriptions, ["channel-eight"], event_number)
    end
  end
end
