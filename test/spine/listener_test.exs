defmodule Spine.ListenerTest do
  use ExUnit.Case
  use Test.Support.Mox

  defmodule MyApp do
    use Spine, event_store: EventStoreMock, bus: BusDbMock
  end

  test "can start the listener" do
    config = %{
      channel: "my-channel"
    }

    assert {:ok, pid} = Spine.Listener.start_link(config)
    assert is_pid(pid)
  end

  test "init/1 subscribes the listener" do
    config = %{}
    state = {1, config}

    Spine.Listener.init(state)

    assert_receive(:subscribe)
  end

  test "handle_info/1 catches :subscribe message, and starts process work" do
    BusDbMock
    |> expect(:subscribe, fn "my-channel" ->
      {:ok, 5}
    end)

    config = %{
      channel: "my-channel",
      spine: MyApp
    }

    existing_state = {1, config}

    assert {:noreply, {5, config}} == Spine.Listener.handle_info(:subscribe, existing_state)

    assert_receive(:process)
  end

  describe "handle_info/1 :process message" do
    test "when the event does not exist" do
      EventStoreMock
      |> expect(:next_event, fn 7 ->
        {:ok, :no_next_event}
      end)

      config = %{
        channel: "my-channel",
        spine: MyApp,
        callback: ListenerCallbackMock
      }

      existing_state = {7, config}

      assert {:noreply, {7, config}} == Spine.Listener.handle_info(:process, existing_state)

      assert_receive(:process)
    end

    test "when the next event does exist, and event_handler returns :ok" do
      event = %{an_event: "yes this is"}

      EventStoreMock
      |> expect(:next_event, fn 7 ->
        # NOTE: as postgres bigserial can have holes,
        # it is possible that event 7 and 8 do not exist.
        # therefore returning 9 is valid
        {:ok, 9, event}
      end)

      ListenerCallbackMock
      |> expect(:handle_event, 1, fn ^event ->
        :ok
      end)

      BusDbMock
      |> expect(:completed, fn "my-channel", 9 ->
        :ok
      end)

      config = %{
        channel: "my-channel",
        spine: MyApp,
        callback: ListenerCallbackMock
      }

      existing_state = {7, config}

      assert {:noreply, {10, config}} == Spine.Listener.handle_info(:process, existing_state)

      assert_receive(:process)
    end

    test "when the next event does exist, and event_handler returns an error" do
      event = %{an_event: "yes this is"}

      EventStoreMock
      |> expect(:next_event, fn 7 ->
        # NOTE: as postgres bigserial can have holes,
        # it is possible that event 7 and 8 do not exist.
        # therefore returning 9 is valid
        {:ok, 9, event}
      end)

      ListenerCallbackMock
      |> expect(:handle_event, 1, fn ^event ->
        {:error, :oh_no}
      end)

      config = %{
        channel: "my-channel",
        spine: MyApp,
        callback: ListenerCallbackMock
      }

      existing_state = {7, config}

      assert {:noreply, {9, config}} == Spine.Listener.handle_info(:process, existing_state)

      assert_receive(:process)
    end
  end
end
