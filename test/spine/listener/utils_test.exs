defmodule Spine.Listener.UtilsTest do
  use ExUnit.Case
  alias Spine.Listener.Utils

  @some_event %{}

  describe "finds current cursor value from a list of events" do
    test "when many events are given" do
      events = [
        {@some_event, %{event_number: 2, aggregate_id: "agg-one"}},
        {@some_event, %{event_number: 6, aggregate_id: "agg-one"}},
        {@some_event, %{event_number: 1, aggregate_id: "agg-two"}},
        {@some_event, %{event_number: 3, aggregate_id: "agg-two"}},
        {@some_event, %{event_number: 5, aggregate_id: "agg-two"}}
      ]

      assert 6 == Utils.find_latest_cursor(events)
    end
  end

  describe "chunks events into aggregate chunks that can be ran concurrently" do
    test "when all events are for the same aggregate" do
      events = [
        {@some_event, %{event_number: 1, aggregate_id: "agg-one"}},
        {@some_event, %{event_number: 2, aggregate_id: "agg-one"}},
        {@some_event, %{event_number: 3, aggregate_id: "agg-one"}},
        {@some_event, %{event_number: 4, aggregate_id: "agg-one"}},
        {@some_event, %{event_number: 5, aggregate_id: "agg-one"}},
        {@some_event, %{event_number: 6, aggregate_id: "agg-one"}}
      ]

      assert [events] == Utils.chunk_by_aggregate(events)
    end

    test "when events are for differing aggregates" do
      events = [
        {@some_event, %{event_number: 1, aggregate_id: "agg-one"}},
        {@some_event, %{event_number: 3, aggregate_id: "agg-one"}},
        {@some_event, %{event_number: 5, aggregate_id: "agg-one"}},
        {@some_event, %{event_number: 2, aggregate_id: "agg-two"}},
        {@some_event, %{event_number: 4, aggregate_id: "agg-two"}},
        {@some_event, %{event_number: 6, aggregate_id: "agg-two"}}
      ]

      assert [
               [
                 {@some_event, %{event_number: 1, aggregate_id: "agg-one"}},
                 {@some_event, %{event_number: 3, aggregate_id: "agg-one"}},
                 {@some_event, %{event_number: 5, aggregate_id: "agg-one"}}
               ],
               [
                 {@some_event, %{event_number: 2, aggregate_id: "agg-two"}},
                 {@some_event, %{event_number: 4, aggregate_id: "agg-two"}},
                 {@some_event, %{event_number: 6, aggregate_id: "agg-two"}}
               ]
             ] == Utils.chunk_by_aggregate(events)
    end
  end
end
