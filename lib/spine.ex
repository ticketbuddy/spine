defmodule Spine do
  @moduledoc """
  Documentation for Spine.
  """

  defmacro __using__(event_store: event_store, bus: bus) do
    quote do
      require Logger

      @count_from 1

      @event_store unquote(event_store)
      @bus unquote(bus)

      @type events :: any() | List.t()
      @type cursor :: {String.t(), non_neg_integer()}
      @type aggregate_id :: String.t()
      @type event_number :: non_neg_integer()
      @type starting_event_number :: event_number()
      @type channel :: String.t()
      @type wish :: any()
      @type handler :: Atom.t()

      @callback commit(events, cursor) :: :ok
      @callback all_events() :: List.t()
      @callback aggregate_events(aggregate_id) :: List.t()
      @callback event(event_number) :: any()
      @callback subscribe(channel) :: :ok
      @callback subscribe(channel, starting_event_number) :: :ok
      @callback subscriptions() :: map()
      @callback cursor(channel) :: non_neg_integer()
      @callback completed(channel, cursor) :: :ok
      @callback handle(wish) :: :ok | any()
      @callback read(aggregate_id, handler) :: any()

      defdelegate commit(events, cursor), to: @event_store
      defdelegate all_events(), to: @event_store
      defdelegate aggregate_events(aggregate_id), to: @event_store
      defdelegate event(event_number), to: @event_store
      defdelegate next_event(event_number), to: @event_store
      defdelegate subscribe(channel), to: @bus
      defdelegate subscribe(channel, starting_event_number), to: @bus
      defdelegate subscriptions(), to: @bus
      defdelegate cursor(channel), to: @bus
      defdelegate completed(channel, cursor), to: @bus

      def handle(wish) do
        handler = Spine.Wish.aggregate_handler(wish)
        aggregate_id = Spine.Wish.aggregate_id(wish)

        events = aggregate_events(aggregate_id)
        cursor = {aggregate_id, Enum.count(events) + @count_from}

        agg_state = Spine.Aggregate.build_state(aggregate_id, events, handler)

        Logger.debug(
          inspect(%{
            msg: "Processing wish",
            wish: wish,
            cursor: cursor
          })
        )

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
