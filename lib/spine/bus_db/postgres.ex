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
      {:ok, subscription} -> {:ok, subscription.cursor}
      {:error, _changeset} -> {:ok, cursor(repo, channel)}
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
        Logger.debug("[BUS] Fetched: #{channel} at #{cursor}")

        cursor
    end
  end

  def completed(repo, channel, cursor) do
    Logger.debug("[BUS] Completed #{channel} at #{cursor}")

    subscription = repo.get!(Schema.Subscription, channel)

    if subscription.cursor == cursor do
      subscription
      |> Ecto.Changeset.change(cursor: cursor + 1)
      |> repo.update()
      |> case do
        {:ok, _changes} -> :ok
      end
    else
      :ok
    end
  end

  defmacro __using__(repo: repo) do
    quote do
      @behaviour Spine.BusDb
      @repo unquote(repo)
      alias Spine.BusDb.Postgres

      def subscribe(channel, starting_event_number \\ 1) do
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
