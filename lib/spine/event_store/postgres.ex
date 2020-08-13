defmodule Spine.EventStore.Postgres do
  alias __MODULE__.{Commit, Schema}
  require Logger

  def commit(repo, events, cursor) do
    Commit.commit(List.wrap(events), cursor)
    |> repo.transaction()
    |> case do
      {:ok, _results} ->
        Logger.debug("[EventStore] commited events.\n#{inspect(events)}")

        :ok

      error ->
        Logger.warn("[EventStore] event not commited.\n#{inspect(error)}")

        :error
    end
  end

  def all_events(repo) do
    repo.all(Schema.Event)
    |> format_events()
  end

  def aggregate_events(repo, aggregate_id) do
    import Ecto.Query

    from(e in Schema.Event,
      where:
        e.aggregate_id ==
          ^aggregate_id
    )
    |> repo.all()
    |> format_events()
  end

  def event(repo, event_number) do
    Logger.debug("[STORE] Fetched: #{event_number}")

    repo.get_by(Schema.Event, event_number: event_number)
    |> case do
      nil -> nil
      event -> event.data
    end
  end

  defp format_events(events) do
    Enum.map(events, &Map.get(&1, :data))
  end

  defmacro __using__(repo: repo) do
    quote do
      @behaviour Spine.EventStore
      @repo unquote(repo)
      alias Spine.EventStore.Postgres

      @impl Spine.EventStore
      def commit(events, cursor) do
        Postgres.commit(@repo, events, cursor)
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
    end
  end
end
