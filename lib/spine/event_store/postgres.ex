defmodule Spine.EventStore.Postgres do
  alias __MODULE__.{Commit}

  def commit(repo, events, cursor) do
    Commit.commit(List.wrap(events), cursor)
    |> repo.transaction()
    |> case do
      {:ok, _results} -> :ok
      _other -> :error
    end
  end

  def seed(repo, event, aggregate_id) do
    :ok
  end

  def all_events(repo) do
    []
  end

  def aggregate_events(repo, aggregate_events) do
    []
  end

  def event(repo, event_number) do
    :an_event
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
      def seed(event, aggregate_id) do
        Postgres.seed(@repo, event, aggregate_id)
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
