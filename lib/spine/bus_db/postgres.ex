defmodule Spine.BusDb.Postgres do
  alias Spine.BusDb.Postgres.Schema
  require Logger

  def subscribe(repo, channel, starting_event_number) do
    Schema.Subscription.changeset(%{
      channel: channel,
      starting_event_number: starting_event_number,
      cursor: starting_event_number
    })
    |> repo.insert()
    |> case do
      {:ok, subscription} ->
        :telemetry.execute([:spine, :bus_db, :subscription, :ok], %{count: 1}, %{
          channel: channel,
          starting_event_number: starting_event_number
        })

        {:ok, subscription.cursor}

      {:error, error} ->
        :telemetry.execute([:spine, :bus_db, :subscription, :error], %{count: 1}, %{
          error: error,
          channel: channel,
          starting_event_number: starting_event_number
        })

        {:ok, cursor(repo, channel)}
    end
  end

  def subscriptions(repo) do
    repo.all(Schema.Subscription)
    |> Enum.reduce(%{}, fn subscription, acc ->
      Map.put(acc, subscription.channel, subscription.cursor)
    end)
  end

  def cursor(repo, channel) do
    repo.get(Schema.Subscription, channel)
    |> case do
      %{cursor: cursor} ->
        :telemetry.execute([:spine, :bus_db, :get_cursor, :ok], %{count: 1}, %{
          channel: channel,
          cursor: cursor
        })

        cursor
    end
  end

  def completed(repo, channel, cursor) do
    subscription = repo.get!(Schema.Subscription, channel)

    if cursor >= subscription.cursor do
      subscription
      |> Ecto.Changeset.change(cursor: cursor + 1)
      |> repo.update()
      |> case do
        {:ok, _changes} ->
          :telemetry.execute([:spine, :bus_db, :event_completed, :ok], %{count: 1}, %{
            channel: channel,
            cursor: cursor
          })

          :ok
      end
    else
      :telemetry.execute([:spine, :bus_db, :event_completed, :error], %{count: 1}, %{
        channel: channel,
        cursor: cursor,
        current_cursor: subscription.cursor,
        reason: "Completion for previous event"
      })

      :ok
    end
  end

  defmacro __using__(repo: repo) do
    quote do
      @behaviour Spine.BusDb
      @repo unquote(repo)
      alias Spine.BusDb.Postgres

      def subscribe(channel, starting_event_number) do
        Postgres.subscribe(@repo, channel, starting_event_number)
      end

      def subscriptions do
        Postgres.subscriptions(@repo)
      end

      def cursor(channel) do
        Postgres.cursor(@repo, channel)
      end

      def completed(channel, cursor) do
        Postgres.completed(@repo, channel, cursor)
      end
    end
  end
end
