defmodule Spine.Listener.Callback do
  @type meta :: %{channel: String.t(), cursor: integer()}
  @type aggregate_id :: String.t()

  @callback handle_event(any, meta) :: :ok | any
  @callback concurrency() :: :single | :by_aggregate
  @callback variant(aggregate_id) :: String.t()
  @callback channel() :: String.t()

  defmacro __using__(opts) do
    quote do
      @behaviour Spine.Listener.Callback

      @channel Keyword.fetch!(unquote(opts), :channel)
      @concurrency Keyword.get(unquote(opts), :concurrency, :single)

      def concurrency, do: @concurrency

      def channel, do: @channel

      def variant(aggregate_id) do
        case concurrency() do
          :single -> "single"
          :by_aggregate -> aggregate_id
        end
      end
    end
  end
end
