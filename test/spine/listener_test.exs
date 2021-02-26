defmodule Spine.ListenerTest do
  use ExUnit.Case
  use Test.Support.Mox

  defmodule MyApp do
    use Spine, event_store: EventStoreMock, bus: BusDbMock
  end

  test "can start the listener" do
    config = %{
      channel: "my-channel",
      callback: nil,
      spine: nil,
      notifier: nil
    }

    assert {:ok, pid} = Spine.Listener.start_link(config)
    assert is_pid(pid)
  end

  test "sets start listening on event number" do
    start_listening_from_event = 3

    BusDbMock
    |> expect(:subscribe, fn "my-other-channel", start_listening_from_event ->
      {:ok, start_listening_from_event}
    end)

    ListenerNotifierMock
    |> expect(:subscribe, fn -> :ok end)

    config = %{
      channel: "my-other-channel",
      callback: nil,
      spine: MyApp,
      notifier: ListenerNotifierMock,
      starting_event_number: start_listening_from_event
    }

    assert {:ok, pid} = Spine.Listener.start_link(config)
    assert is_pid(pid)

    assert {start_listening_from_event,
            %{
              channel: "my-other-channel",
              callback: nil,
              spine: MyApp,
              notifier: ListenerNotifierMock,
              starting_event_number: start_listening_from_event
            }} == :sys.get_state(pid)
  end

  test "when incorrect listener params are provided" do
    config = %{}

    assert_raise(RuntimeError, fn ->
      Spine.Listener.start_link(config)
    end)
  end

  test "init/1 subscribes the listener" do
    config = %{}
    state = {1, config}

    Spine.Listener.init(state)

    assert_receive(:subscribe)
  end

  test "handle_info/1 catches :subscribe message, and starts process work" do
    start_listening_from_event = 5

    BusDbMock
    |> expect(:subscribe, fn "my-channel", ^start_listening_from_event ->
      {:ok, start_listening_from_event}
    end)

    ListenerNotifierMock
    |> expect(:subscribe, fn -> :ok end)

    config = %{
      channel: "my-channel",
      spine: MyApp,
      notifier: ListenerNotifierMock,
      starting_event_number: start_listening_from_event
    }

    existing_state = {start_listening_from_event, config}

    assert {:noreply, {start_listening_from_event, config}} ==
             Spine.Listener.handle_info(:subscribe, existing_state)

    assert_receive(:process)
  end

  describe "handle_info/1 :process message" do
    test "when the event does not exist, do not send :process message" do
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

      refute_receive(:process)
    end

    test "when the next event does exist, and event_handler returns :ok" do
      event = %{an_event: "yes this is"}

      EventStoreMock
      |> expect(:next_event, fn 7 ->
        # NOTE: as postgres bigserial can have holes,
        # it is possible that event 7 and 8 do not exist.
        # therefore returning 9 is valid

        {:ok, event, %{event_number: 9, inserted_at: ~U[2020-11-17 19:06:46Z]}}
      end)

      ListenerCallbackMock
      |> expect(:handle_event, 1, fn ^event, %{channel: "my-channel", cursor: 9} ->
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
        {:ok, event, %{event_number: 9, inserted_at: ~U[2020-11-17 19:06:46Z]}}
      end)

      ListenerCallbackMock
      |> expect(:handle_event, 1, fn ^event, %{channel: "my-channel", cursor: 9} ->
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

  test "catches stray info messages" do
    message = :anything
    state = :shrug

    assert {:noreply, state} == Spine.Listener.handle_info(message, state)
  end
end
