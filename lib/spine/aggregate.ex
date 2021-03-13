defmodule Spine.Aggregate do
  def build_state(aggregate_id, events, handler, init_state \\ nil) do
    :telemetry.execute([:spine, :aggregate, :building_state], %{count: 1}, %{
      aggregate_id: aggregate_id,
      handler: handler
    })

    Enum.reduce(events, init_state, fn event, agg_state ->
      event = Spine.Event.Upcast.upcast(event)
      handler.next_state(agg_state, event)
    end)
  end
end
