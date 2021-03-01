defmodule SpineTest do
  use ExUnit.Case
  use Test.Support.Mox

  use Test.Support.Helper, repo: Test.Support.Repo

  setup do
    Test.Support.Helper.start_test_application!()

    :ok
  end

  test "handling a wish that is allowed" do
    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    assert :ok == App.handle(wish)
  end

  # test "handling a wish that requires strong consistency" do
  #   wish = %EventCatalog.Inc{counter_id: "counter-1"}
  #
  #   assert :ok = MyApp.handle(wish, strong_consistency: ["some-channel"])
  # end
  #
  # test "handling a wish that requires strong consistency times out" do
  #   wish = %EventCatalog.Inc{counter_id: "counter-1"}
  #
  #   assert {:timeout, event_number} =
  #            MyApp.handle(wish, strong_consistency: ["some-channel"], consistency_timeout: 0)
  #
  #   assert is_integer(event_number)
  #   assert :ok == MyApp.wait_for_consistency(["some-channel"], event_number)
  # end

  test "handling a wish, that is not allowed" do
    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: -1
    }

    assert {:error, :amount_must_be_positive} == App.handle(wish)
  end

  test "can read the state of an aggregate back" do
    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    App.handle(wish)
    App.handle(wish)

    assert 9_000 == App.read("account-1", App.BankAc)
  end

  test "events are handled by a listener" do
    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    App.handle(wish)

    assert_receive({:handling_event, _handled_at, [%App.FundsAdded{}, _meta]})
  end

  test "when an event is committed to the event store, a message is broadcasted on commit notifier" do
    App.CommitNotifier.subscribe()

    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    App.handle(wish)

    assert_receive(:process)
  end

  test "when an event is completed by a listener, a message is broadcasted on bus notifier" do
    App.BusNotifier.subscribe()

    wish = %App.AddFunds{
      account_id: "account-1",
      reply_pid: self(),
      amount: 4_500
    }

    App.handle(wish)
    assert_receive({:listener_completed_event, "read_model", 1})
  end
end
