defmodule Spine do
  @moduledoc """
  Documentation for Spine.
  """

  defmacro __using__(event_store: event_store, bus: bus) do
    quote do
      require Logger

      @count_from 1
      @default_consistency_timeout 5_000

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
      @type next_event_opts :: Keyword.t()
      @type opts :: [] | [idempotent_key: String.t()]
      @type variant :: String.t()

      @callback commit(events, cursor) :: :ok
      @callback all_events() :: List.t()
      @callback aggregate_events(aggregate_id) :: List.t()
      @callback event(event_number) :: any()
      @callback subscribe(channel, variant, starting_event_number) :: :ok
      @callback subscriptions() :: map()
      @callback cursor(channel, variant) :: non_neg_integer()
      @callback completed(channel, variant, cursor) :: :ok
      @callback handle(wish) :: :ok | any()
      @callback handle(wish, opts) :: :ok | any()
      @callback read(aggregate_id, handler) :: any()
      @callback event_completed_notifier() :: Module.t()
      @callback all_variants((() -> List.t()), Spine.BusDb.all_variants_opts()) :: {:ok, :ok}

      defdelegate commit(events, cursor, opts), to: @event_store
      defdelegate all_events(), to: @event_store
      defdelegate aggregate_events(aggregate_id), to: @event_store
      defdelegate event(event_number), to: @event_store
      defdelegate next_event(event_number, next_event_opts), to: @event_store
      defdelegate subscribe(channel, variant, starting_event_number), to: @bus
      defdelegate subscriptions(), to: @bus
      defdelegate cursor(channel, variant), to: @bus
      defdelegate completed(channel, variant, cursor), to: @bus
      defdelegate event_completed_notifier(), to: @bus
      defdelegate all_variants(callback, query_opts), to: @bus

      def handle(wish, opts \\ []) do
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
             commited_result <- commit(List.wrap(events), cursor, opts),
             :ok <- handle_consistency_guarantee(aggregate_id, commited_result, opts) do
          :ok
        end
      end

      def read(aggregate_id, handler) do
        events = aggregate_events(aggregate_id)

        Spine.Aggregate.build_state(aggregate_id, events, handler)
      end

      defp handle_consistency_guarantee(aggregate_id, commited_result, opts) do
        case commited_result do
          {:ok, :idempotent} ->
            :ok

          {:ok, event_number} when is_integer(event_number) ->
            do_handle_consistency_guarantee(aggregate_id, event_number, opts)

          :error ->
            :error
        end
      end

      defp do_handle_consistency_guarantee(aggregate_id, event_number, opts) do
        case Keyword.get(opts, :strong_consistency, []) do
          [] ->
            :ok

          channels ->
            timeout = Keyword.get(opts, :consistency_timeout, @default_consistency_timeout)

            Spine.Consistency.wait_for_event(
              aggregate_id,
              event_completed_notifier(),
              channels,
              event_number,
              timeout
            )
        end
      end
    end
  end
end
