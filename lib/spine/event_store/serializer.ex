defmodule Spine.EventStore.Serializer do
  @moduledoc """
  For the writing and reading of events in the event store.
  """

  def serialize(event) do
    event
    |> Map.from_struct()
    |> Map.merge(%{__struct__: to_string(event.__struct__)})
    |> Jason.encode!()
  end

  def deserialize(serialized_event) do
    serialized_event
    |> Jason.decode!()
    |> top_level_keys_to_atoms()
    |> decode()
  end

  defp top_level_keys_to_atoms(map) do
    map
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
  end

  def decode(event_map) do
    new_event = event_map |> Enum.reduce(%{}, fn {key, val}, acc -> Map.put(acc, key, val) end)
    [Map.fetch!(new_event, :__struct__)] |> Module.concat() |> struct(new_event)
  end
end
