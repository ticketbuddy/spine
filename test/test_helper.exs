Mox.defmock(EventStoreMock, for: Spine.EventStore)
Mox.defmock(BusDbMock, for: Spine.BusDb)
Mox.defmock(ListenerCallbackMock, for: Spine.Listener.Callback)
Mox.defmock(CommitNotifierMock, for: Spine.Listener.Notifier)
Mox.defmock(BusNotifierMock, for: Spine.Listener.Notifier)

ExUnit.start()
