defmodule Spine.Listener do
  use GenServer

  # def handle_cast(:new_event, state) do
  #   {cursor, pending_events} = state
  #   {:noreply, {cursor, pending_events + 1}}
  # end
  #
  # def handle_cast(:process, state) do
  #   {cursor, pending_events} = state
  #
  #   # TODO fetch event from event_store, then do_work...
  #   case do_work(cursor) do
  #     :ok -> {cursor + 1, pending_events - 1}
  #     _error ->
  #     # retry logic...
  #     {:noreply, state}
  #   end
  # end
  #
  # defp do_work(event) do
  #   IO.inspect(event, label: "event")
  #
  #   :ok
  # end
end
