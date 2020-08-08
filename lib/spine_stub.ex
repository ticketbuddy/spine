defmodule SpineStub do
  @behvaiour Spine

  def commit(events, cursor), do: :ok
  def all_events(), do: []
  def aggregate_events(aggregate_id), do: []
  def event(event_number), do: nil
  def subscribe(channel), do: :ok
  def subscribe(channel, starting_event_number), do: :ok
  def subscriptions(), do: %{}
  def cursor(channel), do: 1
  def completed(channel, cursor), do: :ok
  def handle(wish), do: :ok
  def read(aggregate_id, handler), do: nil
end
