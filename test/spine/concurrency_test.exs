defmodule Spine.ConcurrencyE2eTest do
  use ExUnit.Case
  use Test.Support.Mox

  use Test.Support.Helper, repo: Test.Support.Repo

  setup do
    Test.Support.Helper.start_test_application!()

    :ok
  end

  test "concurrent handle is called" do
    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    :ok = App.handle(wish)
    assert_receive({:concurrent_handling_event, _handled_at, [_event, _meta]})
  end

  test "concurrently handles events for different aggregates" do
    test_pid = self()

    wish_agg_one = %App.AddFunds{
      account_id: "account-1",
      reply_pid: test_pid,
      amount: 4_500,
      sleep_for: 700
    }

    wish_agg_two = %App.AddFunds{
      account_id: "account-2",
      reply_pid: test_pid,
      amount: 4_500,
      sleep_for: 700
    }

    :ok = App.handle(wish_agg_one)
    :ok = App.handle(wish_agg_two)

    assert_receive(
      {:concurrent_handling_event, handled_one_at, [%{reply_pid: ^test_pid}, _meta]},
      800
    )

    assert_receive(
      {:concurrent_handling_event, handled_second_at, [%{reply_pid: ^test_pid}, _meta]},
      800
    )

    assert DateTime.diff(handled_second_at, handled_one_at, :millisecond) < 50,
           "Events should be processed concurrently"
  end

  test "handle events for the same aggregate in sequence" do
    test_pid = self()

    wish = %App.AddFunds{
      account_id: "account-1-",
      reply_pid: test_pid,
      amount: 8500,
      sleep_for: 700
    }

    :ok = App.handle(wish)
    :ok = App.handle(wish)

    assert_receive(
      {:concurrent_handling_event, handled_one_at, [%{reply_pid: ^test_pid}, _meta]},
      800
    )

    assert_receive(
      {:concurrent_handling_event, handled_second_at, [%{reply_pid: ^test_pid}, _meta]},
      800
    )

    assert DateTime.diff(handled_second_at, handled_one_at, :millisecond) > 700,
           "Events should be processed sequentially"
  end
end
