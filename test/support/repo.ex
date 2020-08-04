defmodule Test.Support.Repo do
  use Ecto.Repo, otp_app: :spine, adapter: Ecto.Adapters.Postgres
end
