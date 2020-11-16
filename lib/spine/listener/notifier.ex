defmodule Spine.Listener.Notifier do
  @moduledoc """
  The behaviour a pubsub must implement, to notify
  listeners of new events.
  """

  @type topic :: String.t()
  @type message :: any()

  @callback subscribe() :: :ok
  @callback broadcast(message) :: :ok
end
