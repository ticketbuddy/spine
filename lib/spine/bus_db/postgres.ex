defmodule Spine.BusDb.Postgres do
  alias Spine.BusDb.Postgres.Schema
  require Logger
  import Ecto.Query, only: [from: 2]

  @chunk_variants 50

  def subscribe(repo, channel, variant, starting_event_number) do
    Schema.Subscription.changeset(%{
      channel: channel,
      starting_event_number: starting_event_number,
      cursor: starting_event_number,
      variant: variant
    })
    |> repo.insert()
    |> case do
      {:ok, subscription} ->
        :telemetry.execute([:spine, :bus_db, :subscription, :ok], %{count: 1}, %{
          channel: channel,
          variant: variant,
          starting_event_number: starting_event_number
        })

        {:ok, subscription.cursor}

      {:error, error} ->
        :telemetry.execute([:spine, :bus_db, :subscription, :error], %{count: 1}, %{
          error: error,
          channel: channel,
          starting_event_number: starting_event_number
        })

        {:ok, cursor(repo, channel, variant)}
    end
  end

  @doc """
  Returns the latest event to be completed for each
  channel.

  WARNING: This does not mean that all events have been completed
  to these returned values.
  """
  def subscriptions(repo) do
    from(s in Schema.Subscription, group_by: [:channel], select: {s.channel, max(s.cursor)})
    |> repo.all()
    |> Map.new()
  end

  def cursor(repo, channel, variant) do
    repo.get_by!(Schema.Subscription, channel: channel, variant: variant)
    |> case do
      %{cursor: cursor} ->
        :telemetry.execute([:spine, :bus_db, :get_cursor, :ok], %{count: 1}, %{
          channel: channel,
          cursor: cursor
        })

        cursor
    end
  end

  def completed(repo, notifier, channel, variant, cursor) do
    # TODO should be done in a transaction?

    subscription = repo.get_by!(Schema.Subscription, channel: channel, variant: variant)

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

          notifier.broadcast({:listener_completed_event, channel, variant, cursor})

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

  defmacro __using__(repo: repo, notifier: notifier) do
    quote do
      @behaviour Spine.BusDb
      @repo unquote(repo)
      @notifier unquote(notifier)
      alias Spine.BusDb.Postgres

      def subscribe(channel, variant, starting_event_number) do
        Postgres.subscribe(@repo, channel, variant, starting_event_number)
      end

      def subscriptions do
        Postgres.subscriptions(@repo)
      end

      def cursor(channel, variant) do
        Postgres.cursor(@repo, channel, variant)
      end

      def completed(channel, variant, cursor) do
        Postgres.completed(@repo, @notifier, channel, variant, cursor)
      end

      def event_completed_notifier, do: @notifier
    end
  end
end
