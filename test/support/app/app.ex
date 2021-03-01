defmodule App do
  defmodule CommitNotifier do
    use Spine.Listener.Notifier.PubSub,
      pubsub: :commit_notifier,
      topic: "commit_notifier"
  end

  defmodule BusNotifier do
    use Spine.Listener.Notifier.PubSub,
      pubsub: :bus_notifier,
      topic: "bus_notifier"
  end

  defmodule EventStore do
    use Spine.EventStore.Postgres, repo: Test.Support.Repo, notifier: CommitNotifier
  end

  defmodule EventBus do
    use Spine.BusDb.Postgres, repo: Test.Support.Repo
  end

  use Spine, event_store: EventStore, bus: EventBus

  import Spine.Wish, only: [defwish: 3]
  import Spine.Event, only: [defevent: 2]

  defwish(AddFunds, [:account_id, :reply_pid, :amount, sleep_for: 0], to: App.BankAc)
  defevent(FundsAdded, [:account_id, :reply_pid, :amount, sleep_for: 0])
end
