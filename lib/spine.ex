defmodule Spine do
  @moduledoc """
  Documentation for Spine.
  """

  defmacro __using__(event_store: event_store, bus: bus) do
    quote do
      defdelegate commit(events, cursor), to: unquote(event_store)
      defdelegate all_events(), to: unquote(event_store)
      defdelegate aggregate_events(), to: unquote(event_store)
      defdelegate event(event_number), to: unquote(event_store)

      defdelegate subscribe(channel), to: unquote(bus)
      defdelegate subscribe(channel, pid), to: unquote(bus)
      defdelegate subscriptions(), to: unquote(bus)
      defdelegate cursor(channel), to: unquote(bus)
      defdelegate completed(channel, cursor), to: unquote(bus)
    end
  end
end
