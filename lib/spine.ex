defmodule Spine do
  @moduledoc """
  Documentation for Spine.
  """

  defmacro __using__(event_store: event_store, bus: bus) do
    quote do
      @event_store unquote(event_store)
      @bus unquote(bus)

      defdelegate commit(events, cursor), to: @event_store
      defdelegate all_events(), to: @event_store
      defdelegate aggregate_events(aggregate_id), to: @event_store
      defdelegate event(event_number), to: @event_store

      defdelegate subscribe(channel), to: @bus
      defdelegate subscribe(channel, pid), to: @bus
      defdelegate subscriptions(), to: @bus
      defdelegate cursor(channel), to: @bus
      defdelegate completed(channel, cursor), to: @bus

      def handle(wish) do
        handler = Spine.Wish.aggregate_handler(wish)
        aggregate_id = Spine.Wish.aggregate_id(wish)

        events = aggregate_events(aggregate_id)
        cursor = {aggregate_id, Enum.count(events)}

        agg_state = Spine.Aggregate.build_state(aggregate_id, events, handler)

        with {:ok, events} <- handler.execute(agg_state, wish),
             :ok <- commit(List.wrap(events), cursor) do
          :ok
        end
      end

      def read(aggregate_id, handler) do
        events = aggregate_events(aggregate_id)

        Spine.Aggregate.build_state(aggregate_id, events, handler)
      end
    end
  end
end
