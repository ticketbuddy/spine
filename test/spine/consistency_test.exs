defmodule Spine.ConsistencyTest do
  use ExUnit.Case
  use Test.Support.Mox
  alias Spine.Consistency

  defmodule MyApp do
    defmodule MyEventStore do
      use Spine.EventStore.Postgres, repo: Test.Support.Repo, notifier: ListenerNotifierMock
    end

    defmodule MyEventBus do
      use Spine.BusDb.Postgres, repo: Test.Support.Repo, notifier: ListenerNotifierMock
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
end
