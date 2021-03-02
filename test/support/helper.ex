defmodule Test.Support.Helper do
  def start_test_application! do
    ExUnit.Callbacks.start_supervised!({Phoenix.PubSub, name: :commit_notifier},
      id: :commit_notifier
    )

    ExUnit.Callbacks.start_supervised!({Phoenix.PubSub, name: :bus_notifier}, id: :bus_notifier)

    ExUnit.Callbacks.start_supervised!(
      {Spine.Listener,
       %{
         notifier: App.CommitNotifier,
         spine: App,
         callback: App.ReadModel,
         channel: "read_model"
       }}
    )
  end

  defmodule MockApp do
    use Spine,
      event_store: EventStoreMock,
      bus: BusDbMock,
      commit_notifier: CommitNotifierMock,
      bus_notifier: BusNotifierMock
  end

  def mocks do
    %{
      channel: "mock-channel",
      callback: ListenerCallbackMock,
      spine: MockApp,
      commit_notifier: CommitNotifierMock,
      bus_notifier: BusNotifierMock
    }
  end

  defmacro __using__(repo: repos) do
    quote do
      setup tags do
        unquote(repos)
        |> List.wrap()
        |> Enum.each(fn repo ->
          start_supervised!(repo)

          :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo)

          unless tags[:async] do
            Ecto.Adapters.SQL.Sandbox.mode(
              repo,
              {:shared, self()}
            )
          end
        end)

        :ok
      end
    end
  end
end
