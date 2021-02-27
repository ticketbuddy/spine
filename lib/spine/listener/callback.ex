defmodule Spine.Listener.Callback do
  @type meta :: %{channel: String.t(), cursor: integer()}
  @type aggregate_id :: String.t()

  @callback handle_event(any, meta) :: :ok | any
  @callback concurrency() :: :single | :by_aggregate
  @callback channel(aggregate_id) :: String.t()
  @callback root_channel() :: String.t()

  defmacro __using__(opts) do
    quote do
      @behaviour Spine.Listener.Callback

      @channel Keyword.fetch!(unquote(opts), :channel)
      @concurrency Keyword.get(unquote(opts), :concurrency, :single)

      def concurrency, do: @concurrency

      def root_channel, do: @channel

      def channel(aggregate_id) do
        case concurrency() do
          :single -> "#{root_channel()}-single"
          :by_aggregate -> "#{root_channel()}-#{aggregate_id}"
        end
      end
    end
  end
end
