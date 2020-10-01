defmodule Spine.EventStore do
  @type event :: any()
  @type events :: [event]
  @type key :: number
  @type aggregate_id :: String.t()
  @type cursor :: {aggregate_id, key}
  @type opts :: [idempotent_key: String.t()] | []

  @callback commit(events, cursor, opts) :: :ok | {:ok, :idempotent} | :error
  @callback all_events() :: events
  @callback aggregate_events() :: aggregate_id
  @callback event(key) :: any()
  @callback next_event(key) :: any()
end
