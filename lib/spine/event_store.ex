defmodule Spine.EventStore do
  @type event :: any()
  @type events :: [event]
  @type key :: number
  @type aggregate_id :: String.t()
  @type cursor :: {aggregate_id, key}
  @type event_number :: Integer.t()
  @type opts :: [idempotent_key: String.t()] | []
  @type channel_type :: :single | :by_aggregate

  @callback commit(events, cursor, opts) :: {:ok, event_number} | {:ok, :idempotent} | :error
  @callback all_events() :: events
  @callback aggregate_events(aggregate_id) :: events
  @callback event(key) :: event
  @callback next_event(key, channel_type) :: event
end
