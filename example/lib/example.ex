defmodule Example do
  use Spine, event_store: Spine.EventStore.Postgres, bus: Spine.BusDb.EphemeralDb
end
