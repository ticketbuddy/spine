import Mix.Config

config :spine, repo: Example.Repo

config :example, ecto_repos: [Example.Repo]

config :example, Example.Repo,
  database: "example",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
