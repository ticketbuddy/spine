defmodule Spine.ListenerTest do
  use ExUnit.Case
  use Test.Support.Mox

  setup do
    mocks = Test.Support.Helper.mocks()

    listener_config = %{
      channel: mocks.channel,
      callback: mocks.callback,
      spine: mocks.spine,
      starting_event_number: 1
    }

    %{
      listener_config: listener_config
    }
  end

  test "can start the listener", %{listener_config: listener_config} do
    assert {:ok, pid} = Spine.Listener.start_link(listener_config)
    assert is_pid(pid)
  end

  test "sets start listening on event number", %{listener_config: listener_config} do
    listener_config = Map.put(listener_config, :starting_event_number, 3)

    expect(BusDbMock, :subscribe, fn "mock-channel", 3 ->
      {:ok, 3}
    end)

    expect(CommitNotifierMock, :subscribe, fn ->
      :ok
    end)

    assert {:ok, pid} = Spine.Listener.start_link(listener_config)
    assert is_pid(pid)
    assert {set_cursor, %{starting_event_number: set_cursor}} = :sys.get_state(pid)
    assert set_cursor = 3
  end

  test "when not all listener params are provided" do
    assert_raise(RuntimeError, fn ->
      Spine.Listener.start_link(%{})
    end)
  end

  test "init/1 subscribes the listener", %{listener_config: listener_config} do
    state = {1, listener_config}

    Spine.Listener.init(state)

    assert_receive(:subscribe)
  end

  test "handle_info/1 catches :subscribe message, and starts process work", %{
    listener_config: config
  } do
    start_listening_from_event = 5
    config = Map.put(config, :starting_event_number, start_listening_from_event)

    expect(BusDbMock, :subscribe, fn "mock-channel", ^start_listening_from_event ->
      {:ok, start_listening_from_event}
    end)

    expect(CommitNotifierMock, :subscribe, fn -> :ok end)

    existing_state = {start_listening_from_event, config}

    assert {:noreply, {start_listening_from_event, config}} ==
             Spine.Listener.handle_info(:subscribe, existing_state)

    assert_receive(:process)
  end

  describe "handle_info/1 :process message" do
    test "when the event does not exist, do not send :process message", %{listener_config: config} do
      expect(EventStoreMock, :next_event, fn 7 ->
        {:ok, :no_next_event}
      end)

      existing_state = {7, config}

      assert {:noreply, {7, config}} == Spine.Listener.handle_info(:process, existing_state)

      refute_receive(:process)
    end

    test "when the next event does exist, and event_handler returns :ok", %{
      listener_config: config
    } do
      event = %{an_event: "yes this is"}

      expect(EventStoreMock, :next_event, fn 7 ->
        # NOTE: as postgres bigserial can have holes,
        # it is possible that event 7 and 8 do not exist.
        # therefore returning 9 is valid

        {:ok, event, %{event_number: 9, inserted_at: ~U[2020-11-17 19:06:46Z]}}
      end)

      expect(ListenerCallbackMock, :handle_event, 1, fn ^event,
                                                        %{channel: "mock-channel", cursor: 9} ->
        :ok
      end)

      expect(BusDbMock, :completed, fn "mock-channel", 9 ->
        :ok
      end)

      expect(BusNotifierMock, :broadcast, fn {:listener_completed_event, "mock-channel", 9} ->
        :ok
      end)

      existing_state = {7, config}

      assert {:noreply, {10, config}} == Spine.Listener.handle_info(:process, existing_state)

      assert_receive(:process)
    end

    test "when the next event does exist, and event_handler returns an error", %{
      listener_config: config
    } do
      event = %{an_event: "yes this is"}

      expect(EventStoreMock, :next_event, fn 7 ->
        # NOTE: as postgres bigserial can have holes,
        # it is possible that event 7 and 8 do not exist.
        # therefore returning 9 is valid
        {:ok, event, %{event_number: 9, inserted_at: ~U[2020-11-17 19:06:46Z]}}
      end)

      expect(ListenerCallbackMock, :handle_event, 1, fn ^event,
                                                        %{channel: "mock-channel", cursor: 9} ->
        {:error, :oh_no}
      end)

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
