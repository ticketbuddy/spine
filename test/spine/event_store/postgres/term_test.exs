defmodule Spine.EventStore.Postgres.TermTest do
  use ExUnit.Case
  alias Spine.EventStore.Postgres.Term

  test "implements equal?/2" do
    assert Term.equal?(5, 5)
  end

  test "implements embed_as/1" do
    assert :self == Term.embed_as("anything")
  end

  test "converts erlang terms" do
    assert {:ok, binary} = Term.dump({:ok, :a_term})

    assert {:ok, loaded} = Term.load(binary)
    assert {:ok, casted} = Term.cast(binary)

    assert loaded == {:ok, :a_term}
    assert casted == {:ok, :a_term}
  end
end
