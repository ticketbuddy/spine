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
