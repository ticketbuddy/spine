defmodule Spine.Aggregate do
  def build_state(aggregate_id, events, handler, init_state \\ nil) do
    Enum.reduce(events, init_state, fn event, agg_state ->
      handler.next_state(agg_state, event)
    end)
  end
end
