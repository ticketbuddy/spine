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
    expect(ListenerCallbackMock, :channel, fn ->
      "channel-one"
    end)

    expect(ListenerNotifierMock, :subscribe, fn ->
      :ok
    end)

    assert {:ok, pid} = Spine.Listener.start_link(config)
    assert is_pid(pid)
    assert Map.put(config, :starting_event_number, 1) == :sys.get_state(pid)
  end
end
