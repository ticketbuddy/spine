defmodule Spine.BusDb do
  @type cursor :: Integer.t()
  @type channel :: String.t()

  @callback subscribe(channel) :: {:ok, cursor}
  @callback subscribe(channel, pid) :: {:ok, cursor}
  @callback subscriptions() :: %{channel => {pid, cursor}}
  @callback cursor(channel) :: cursor
  @callback completed(channel, cursor) :: :ok
end
