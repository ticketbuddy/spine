import Mix.Config

config :spine, ecto_repos: [Test.Support.Repo]

config :logger, level: :warn

config :spine, Test.Support.Repo,
  database: "spine",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
