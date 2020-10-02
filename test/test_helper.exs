Mox.defmock(EventStoreMock, for: Spine.EventStore)
Mox.defmock(BusDbMock, for: Spine.BusDb)
Mox.defmock(ListenerCallbackMock, for: Spine.Listener.Callback)

ExUnit.start()

alias Test.Support.Repo

{:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(Repo, :temporary)
{:ok, _pid} = Repo.start_link()
