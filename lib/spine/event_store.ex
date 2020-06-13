defmodule Spine.EventStore do
  @type events :: [map()]
  @type aggregate_cursor :: number
  @type aggregate_id :: String.t()

  @callback commit(events) :: {:ok, aggregate_cursor}
end
