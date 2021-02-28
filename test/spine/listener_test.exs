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

    expect(ListenerCallbackMock, :concurrency, fn -> :single end)

    expect(ListenerCallbackMock, :variant, fn -> "single" end)

    expect(ListenerNotifierMock, :subscribe, fn ->
      :ok
    end)

    assert {:ok, pid} = Spine.Listener.start_link(config)
    assert is_pid(pid)
    assert Map.put(config, :starting_event_number, 1) == :sys.get_state(pid)
  end

  describe "on listener init" do
    setup do
      stub(ListenerNotifierMock, :subscribe, fn -> :ok end)

      stub(ListenerCallbackMock, :concurrency, fn -> :single end)

      :ok
    end

    test "subscribes to notifier", %{
      config: config
    } do
      expect(ListenerNotifierMock, :subscribe, fn -> :ok end)

      assert {:ok, config} == Spine.Listener.init(config)
    end

    test "when concurrency: :single, starts processing single stream", %{
      config: config
    } do
      expect(ListenerCallbackMock, :concurrency, fn -> :single end)

      assert {:ok, config} == Spine.Listener.init(config)
      assert_receive(:process)
    end

    test "when concurrency: :by_aggregate, starts processing all aggregates", %{
      config: config
    } do
      expect(ListenerCallbackMock, :concurrency, fn -> :by_aggregate end)

      assert {:ok, config} == Spine.Listener.init(config)
      assert_receive(:process_all_aggregates)
    end
  end

  test "receive :process_all_aggregates, starts processing all aggregates", %{config: config} do
    config = Map.put(config, :starting_event_number, 1)

    expect(ListenerCallbackMock, :channel, 3, fn ->
      "some-channel"
    end)

    expect(ListenerCallbackMock, :variant, 3, fn
      aggregate_id -> aggregate_id
    end)

    expect(EventStoreMock, :all_aggregates, fn callback ->
      callback.(["aggregate-one", "aggregate-two", "aggregate-three"])

      {:ok, :ok}
    end)

    assert {:noreply, config} == Spine.Listener.handle_info(:process_all_aggregates, config)

    assert %{active: 3, specs: 3, supervisors: 0, workers: 3} =
             DynamicSupervisor.count_children(FakeListenerDynamicSupervisor)
  end
end
