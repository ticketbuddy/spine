defprotocol Spine.Event.Upcast do
  @fallback_to_any true
  @spec upcast(event :: struct()) :: struct()

  def upcast(event)
end

defimpl Spine.Event.Upcast, for: Any do
  @moduledoc """
  The default implementation, returns unchanged event.
  """

  def upcast(event), do: event
end
