defmodule Spine.Bus do
  @type cursor :: Integer.t()
  @type channel :: String.t()

  @callback subscribe(channel) :: :ok
  @callback subscribe(channel, pid) :: :ok
  @callback subscriptions() :: %{channel => {pid, cursor}}
  @callback cursor(channel) :: cursor
  @callback completed(channel, cursor) :: :ok
end
