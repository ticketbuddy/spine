ExUnit.start()

alias Test.Support.Repo
{:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(Repo, :temporary)

# This cleans up the test database and loads the schema
Mix.Task.run("ecto.drop")
Mix.Task.run("ecto.create")

# Start a process ONLY for our test run.
{:ok, _pid} = Repo.start_link()
