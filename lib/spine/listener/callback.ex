defmodule Spine.Listener.Callback do
  @type meta :: %{channel: String.t(), cursor: integer()}

  @callback handle_event(any, meta) :: :ok | any
end
