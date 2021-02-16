defmodule Spine.BusDb do
  @type cursor :: Integer.t()
  @type channel :: String.t()
  @type starting_event_number :: Integer.t()

  @callback subscribe(channel, starting_event_number) :: {:ok, cursor}
  @callback subscriptions() :: %{channel => {pid, cursor}}
  @callback cursor(channel) :: cursor
  @callback completed(channel, cursor) :: :ok
end
