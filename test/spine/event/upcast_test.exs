defmodule Spine.Event.UpcastTest do
  use ExUnit.Case
  use Test.Support.Mox

  use Test.Support.Helper, repo: Test.Support.Repo

  setup do
    Test.Support.Helper.start_test_application!()

    :ok
  end

  test "events are upcasted before being used to build aggregate state" do
    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    App.handle(wish)
    App.read("account-1", App.BankAc)

    assert_receive({:building_state, [_state, %App.FundsAdded{version: 1}]})
  end

  test "events are upcasted before being handled by listener" do
    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    App.handle(wish)

    assert_receive({:handling_event, _handled_at, [%App.FundsAdded{version: 1}, _meta]})
  end
end
