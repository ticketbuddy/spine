defmodule Spine.EventStore.Postgres do
  alias __MODULE__.{Commit, Schema}
  require Logger

  def commit(repo, notifier, events, cursor, opts) do
    events = List.wrap(events)

    Commit.commit(events, cursor, opts)
    |> repo.transaction()
    |> case do
      {:ok, _results} ->
        :telemetry.execute([:spine, :event_store, :commit, :ok], %{count: Enum.count(events)}, %{
          cursor: cursor
        })

        notifier.broadcast(:process)

        :ok

      {:error, {:idempotent_check}, _changeset, _data} ->
        :telemetry.execute(
          [:spine, :event_store, :commit, :idempotent],
          %{count: Enum.count(events)},
          %{
            cursor: cursor
          }
        )

        {:ok, :idempotent}

      error ->
        :telemetry.execute(
          [:spine, :event_store, :commit, :error],
          %{count: Enum.count(events)},
          %{cursor: cursor, error: error}
        )

        :error
    end
  end

  def all_events(repo) do
    repo.all(Schema.Event)
    |> format_events()
  end

  def aggregate_events(repo, aggregate_id) do
    import Ecto.Query

    :telemetry.execute([:spine, :event_store, :load_aggregate], %{count: 1}, %{
      aggregate_id: aggregate_id
    })

    from(e in Schema.Event,
      where:
        e.aggregate_id ==
          ^aggregate_id,
      order_by: [asc: e.event_number]
    )
    |> repo.all()
    |> format_events()
  end

  def event(repo, event_number) do
    repo.get_by(Schema.Event, event_number: event_number)
    |> case do
      nil ->
        :telemetry.execute([:spine, :event_store, :get_event, :missed], %{count: 1}, %{
          event_number: event_number
        })

        nil

      event ->
        :telemetry.execute([:spine, :event_store, :get_event, :ok], %{count: 1}, %{
          event_number: event_number
        })

        event.data
    end
  end

  @doc """
  event_number is stored as `bigserial`.
  This means there can be gaps.
  e.g 1, 2, 3, 5, 6, 7, 9

  This function will return the next event, when
  given an event_number.
  """
  def next_event(repo, event_number) do
    import Ecto.Query

    from(e in Schema.Event,
      where: e.event_number >= ^event_number,
      order_by: [asc: e.event_number],
      limit: 1
    )
    |> repo.one()
    |> case do
      nil ->
        {:ok, :no_next_event}

      e = %Spine.EventStore.Postgres.Schema.Event{
        data: data,
        event_number: event_number,
        inserted_at: inserted_at
      } ->
        {:ok, data, %{event_number: event_number, inserted_at: inserted_at}}
    end
  end

  defp format_events(events) do
    Enum.map(events, &Map.get(&1, :data))
  end

  defmacro __using__(repo: repo, notifier: notifier) do
    quote do
      @behaviour Spine.EventStore
      @repo unquote(repo)
      @notifier unquote(notifier)

      alias Spine.EventStore.Postgres

      @impl Spine.EventStore
      def commit(events, cursor, opts) do
        Postgres.commit(@repo, @notifier, events, cursor, opts)
      end

      @impl Spine.EventStore
      def all_events do
        Postgres.all_events(@repo)
      end

      @impl Spine.EventStore
      def aggregate_events(aggregate_events) do
        Postgres.aggregate_events(@repo, aggregate_events)
      end

      @impl Spine.EventStore
      def event(event_number) do
        Postgres.event(@repo, event_number)
      end

      @impl Spine.EventStore
      def next_event(event_number) do
        Postgres.next_event(@repo, event_number)
      end
    end
  end
end
