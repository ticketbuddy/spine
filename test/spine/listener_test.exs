defmodule Spine.ListenerTest do
  use ExUnit.Case
  use Test.Support.Mox

  defmodule MyApp do
    use Spine, event_store: EventStoreMock, bus: BusDbMock
  end

  setup do
    start_supervised!(
      {DynamicSupervisor, strategy: :one_for_one, name: FakeListenerDynamicSupervisor}
    )

    %{
      config: %{
        listener_supervisor: FakeListenerDynamicSupervisor,
        notifier: ListenerNotifierMock,
        spine: MyApp,
        callback: ListenerCallbackMock
      }
    }
  end

  test "starts a listener", %{config: config} do
    expect(ListenerCallbackMock, :channel, 2, fn ->
      "channel-one"
    end)

    expect(ListenerNotifierMock, :subscribe, fn ->
      :ok
    end)

    assert {:ok, pid} = Spine.Listener.start_link(config)
    assert is_pid(pid)
    assert Map.put(config, :starting_event_number, 1) == :sys.get_state(pid)
  end

  test "on listener init, subscribes to notifier, and starts processing all aggregates", %{
    config: config
  } do
    expect(ListenerNotifierMock, :subscribe, fn -> :ok end)

    assert {:ok, config} == Spine.Listener.init(config)
    assert_receive(:check_for_previous_events)
  end

  test "receive :check_for_previous_events, starts processing all aggregates", %{config: config} do
    config = Map.put(config, :starting_event_number, 1)

    expect(ListenerCallbackMock, :channel, fn ->
      "some-channel"
    end)

    assert {:noreply, config} == Spine.Listener.handle_info(:check_for_previous_events, config)

    assert %{active: 1, specs: 1, supervisors: 0, workers: 1} =
             DynamicSupervisor.count_children(FakeListenerDynamicSupervisor)
  end
end
