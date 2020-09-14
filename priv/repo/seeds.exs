alias Spine.EventStore.Postgres.Schema.Event
alias Test.Support.Repo

{:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(Repo, :temporary)
{:ok, _pid} = Repo.start_link()


event = %TestApp.Incremented{}

%Event{
  aggregate_id: "seeded-aggregate-1",
  event_number: 1,
  aggregate_number: 1,
  data: event
}
|> Repo.insert!()

%Event{
  aggregate_id: "seeded-aggregate-2",
  event_number: 2,
  aggregate_number: 1,
  data: event
}
|> Repo.insert!()

%Event{
  aggregate_id: "seeded-aggregate-2",
  event_number: 4,
  aggregate_number: 2,
  data: event
}
|> Repo.insert!()

%Event{
  aggregate_id: "seeded-aggregate-2",
  event_number: 5,
  aggregate_number: 3,
  data: event
}
|> Repo.insert!()

IO.puts "Seeded."
