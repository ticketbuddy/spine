defmodule Spine.EventTest do
  use ExUnit.Case

  defmodule MyApp do
    import Spine.Event
    defevent(SmallEvent, [:id, count: 1])
  end

  defmodule ExplicitEvent do
    use Spine.Event, attributes: [:id, count: 1]
  end

  test "builds enforced keys" do
    assert [:id] == Spine.Event.encorced_keys([:id, foo: "bar"])
  end

  describe "ExplicitEvent" do
    test "defines an event" do
      assert %ExplicitEvent{id: "counter-a", count: 1} == %ExplicitEvent{id: "counter-a"}
    end
  end

  describe "SmallEvent" do
    test "defines an event" do
      assert %MyApp.SmallEvent{id: "counter-a", count: 1} == %MyApp.SmallEvent{id: "counter-a"}
    end
  end
end
