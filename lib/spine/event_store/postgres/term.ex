defmodule Spine.EventStore.Postgres.Term do
  @behaviour Ecto.Type
  def type, do: :binary
  def cast(term) when is_binary(term), do: {:ok, term |> :erlang.binary_to_term()}
  def cast(term), do: {:ok, term}

  def load(term) when is_binary(term), do: {:ok, term |> :erlang.binary_to_term()}
  def load(term), do: {:ok, term}

  def dump(term) when is_binary(term), do: {:ok, term}
  def dump(term), do: {:ok, term |> :erlang.term_to_binary()}
end
