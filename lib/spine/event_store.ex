defmodule Spine.EventStore do
  @type event :: any()
  @type events :: [event]
  @type key :: number
  @type aggregate_id :: String.t()
  @type cursor :: {aggregate_id, key}

  @callback commit(events, cursor) :: :ok
  @callback seed(event, aggregate_id) :: :ok
  @callback all_events() :: events
  @callback aggregate_events(aggregate_id) :: events
  @callback event(key) :: any()
end
