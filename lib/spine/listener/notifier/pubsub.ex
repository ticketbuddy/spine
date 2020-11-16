defmodule Spine.Listener.Notifier.PubSub do
  defmacro __using__(pubsub: pubsub, topic: topic) do
    quote do
      @behaviour Spine.Listener.Notifier
      @pubsub unquote(pubsub)
      @topic unquote(topic)

      def subscribe do
        Phoenix.PubSub.subscribe(@pubsub, @topic)
      end

      def broadcast(message) do
        Phoenix.PubSub.broadcast(@pubsub, @topic, message)
      end
    end
  end
end
