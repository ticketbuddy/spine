defmodule Spine.ConsistencyE2eTest do
  use ExUnit.Case
  use Test.Support.Mox

  use Test.Support.Helper, repo: Test.Support.Repo

  setup do
    Test.Support.Helper.start_test_application!()

    :ok
  end

  test "eventual consistency, receives result before listener has completed" do
    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    result = App.handle(wish)
    result_received_at = DateTime.utc_now()

    listener_handled_at =
      receive do
        {:handling_event, handled_at, [_event, _meta]} -> handled_at
      end

    assert :ok == result
    assert :lt == DateTime.compare(result_received_at, listener_handled_at)
  end

  test "strong consistency, receives result after listener has completed" do
    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    result = App.handle(wish, strong_consistency: [@channel])
    result_received_at = DateTime.utc_now()

    listener_handled_at =
      receive do
        {:handling_event, handled_at, [_event, _meta]} -> handled_at
      end

    assert :ok == result
    assert :gt == DateTime.compare(result_received_at, listener_handled_at)
  end

  test "strong consistency, when listener handler times out" do
    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    result =
      App.handle(wish,
        strong_consistency: [@channel],
        consistency_timeout: 500
      )

    result_received_at = DateTime.utc_now()

    listener_handled_at =
      receive do
        {:handling_event, handled_at, [_event, _meta]} -> handled_at
      end

    assert {:timeout, event_number} = result
    assert is_integer(event_number)
    assert :lt == DateTime.compare(result_received_at, listener_handled_at)
  end
end
