defmodule Spine.Consistency.Utils do
  @doc """
  `subscriptions` map values are  event numbers that the channel is
  looking to complete next.

  Therefore, if the subscription number is greater than the desired
  event number to reach consistency, then we we have achieved consistency.
  """
  def is_consistent?(subscriptions, channels, event_number) do
    subscriptions
    |> Map.take(channels)
    |> Map.values()
    |> raise_if_empty!(channels)
    |> Enum.all?(&(&1 > event_number))
  end

  defp raise_if_empty!(channel_values, channels) do
    case Enum.count(channel_values) == Enum.count(channels) do
      true -> channel_values
      false -> raise("Ensure channels that require strong consistency exist.")
    end
  end
end
