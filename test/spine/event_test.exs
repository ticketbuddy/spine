defmodule Spine.EventTest do
  use ExUnit.Case

  defmodule MyApp do
    import Spine.Event
    defevent(ShorthandEvent, [:id, count: 1])
  end

  defmodule ModuleEvent do
    use Spine.Event, attributes: [:id, count: 1]
  end

  test "builds enforced keys" do
    assert [:id] == Spine.Event.encorced_keys([:id, foo: "bar"])
  end

  describe "ModuleEvent" do
    test "defines an event" do
      assert %ModuleEvent{id: "counter-a", count: 1} == %ModuleEvent{id: "counter-a"}
    end
  end

  describe "ShorthandEvent" do
    test "defines an event" do
      assert %MyApp.ShorthandEvent{id: "counter-a", count: 1} == %MyApp.ShorthandEvent{
               id: "counter-a"
             }
    end
  end
end
