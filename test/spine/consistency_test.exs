defmodule Spine.ConsistencyTest do
  use ExUnit.Case
  use Test.Support.Mox
  alias Spine.Consistency

  defmodule MyApp do
    defmodule MyEventStore do
      use Spine.EventStore.Postgres, repo: Test.Support.Repo, notifier: ListenerNotifierMock
    end

    defmodule MyEventBus do
      use Spine.BusDb.Postgres, repo: Test.Support.Repo
    end

    use Spine, event_store: EventStoreMock, bus: BusDbMock
  end

  setup do
    %{config: %{spine: MyApp, notifier: ListenerNotifierMock}}
  end

  test "starts consistency GenServer", %{config: config} do
    assert {:ok, pid} = Consistency.start_link(config)
    assert is_pid(pid)
  end

  test "on init, starts do_poll message loop", %{config: config} do
    assert {:ok, config} == Consistency.init(config)

    assert_receive(:do_poll)
  end

  test "handle_info :do_poll, will collect subscriptions, broadcast them, and schedule the next",
       %{config: config} do
    fake_subscriptions = %{
      "listener-one" => 2_332_455,
      "listener-two" => 2384,
      "listener-three" => 75833
    }

    BusDbMock
    |> expect(:subscriptions, fn ->
      fake_subscriptions
    end)

    ListenerNotifierMock
    |> expect(:broadcast, fn {:listener_progress_update, ^fake_subscriptions} ->
      :ok
    end)

    assert {:noreply, config} == Spine.Consistency.handle_info(:do_poll, config)

    assert_receive(:do_poll, 1_500)
  end

  describe "wait_for_event/3" do
    test "raises when a strongly consistent channel does not exist", %{config: config} do
      event_number = 200

      strongly_consistent_channels = ["I_DO_NOT_EXIST"]

      subscriptions = %{
        "one" => 200,
        "two" => 199,
        "three" => 150
      }

      BusDbMock
      |> expect(:subscriptions, fn ->
        subscriptions
      end)

      stub(ListenerNotifierMock, :subscribe, fn -> :ok end)
      stub(ListenerNotifierMock, :broadcast, fn _subscriptions -> :ok end)

      assert {:ok, _pid} = Consistency.start_link(config)

      assert_raise RuntimeError, fn ->
        send(self(), {:listener_progress_update, subscriptions})
        Spine.Consistency.wait_for_event(strongly_consistent_channels, event_number, 1_000)
      end
    end

    test "when waiting reaches timeout", %{config: config} do
      event_number = 200

      initial_subscriptions = %{
        "one" => 200,
        "two" => 199,
        "three" => 150
      }

      strongly_consistent_subscriptions = %{
        "one" => 200,
        "two" => 200,
        "three" => 150
      }

      strongly_consistent_channels = ["one", "two"]

      BusDbMock
      |> expect(:subscriptions, fn ->
        initial_subscriptions
      end)

      ListenerNotifierMock
      |> expect(:broadcast, fn {:listener_progress_update, ^initial_subscriptions} ->
        :ok
      end)

      expect(ListenerNotifierMock, :subscribe, fn -> :ok end)

      assert {:ok, _pid} = Consistency.start_link(config)

      test_pid = self()

      spawn(fn ->
        :timer.sleep(800)
        send(test_pid, {:listener_progress_update, strongly_consistent_subscriptions})
      end)

      assert {:timeout, event_number} ==
               Spine.Consistency.wait_for_event(strongly_consistent_channels, event_number, 600)
    end

    test "when subscriptions are strongly consistent", %{config: config} do
      event_number = 200

      initial_subscriptions = %{
        "one" => 199,
        "two" => 200,
        "three" => 150
      }

      strongly_consistent_subscriptions = %{
        "one" => 200,
        "two" => 200,
        "three" => 150
      }

      strongly_consistent_channels = ["one", "two"]

      BusDbMock
      |> expect(:subscriptions, fn ->
        initial_subscriptions
      end)

      ListenerNotifierMock
      |> expect(:broadcast, fn {:listener_progress_update, ^initial_subscriptions} ->
        :ok
      end)

      expect(ListenerNotifierMock, :subscribe, fn -> :ok end)

      assert {:ok, _pid} = Consistency.start_link(config)

      test_pid = self()

      spawn(fn ->
        :timer.sleep(150)
        send(test_pid, {:listener_progress_update, strongly_consistent_subscriptions})
      end)

      assert :ok ==
               Spine.Consistency.wait_for_event(strongly_consistent_channels, event_number, 600)
    end
  end

  test "catches stray info messages" do
    message = :anything
    state = :shrug

    assert {:noreply, state} == Spine.Listener.handle_info(message, state)
  end
end
