defmodule Spine.Listener.Callback do
  @callback handle_event(any) :: :ok | any
end
