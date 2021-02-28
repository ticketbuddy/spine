defmodule Spine.BusDb do
  @type cursor :: Integer.t()
  @type channel :: String.t()
  @type variant :: String.t()
  @type starting_event_number :: Integer.t()
  @type all_variants_opts :: [channel: String.t()]

  @callback subscribe(channel, variant, starting_event_number) :: {:ok, cursor}
  @callback subscriptions() :: %{channel => {pid, cursor}}
  @callback cursor(channel, variant) :: cursor
  @callback completed(channel, variant, cursor) :: :ok
  @callback event_completed_notifier() :: Module.t()
  @callback all_variants((() -> List.t()), all_variants_opts) :: {:ok, :ok}
end
