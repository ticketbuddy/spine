alias Spine.EventStore.Postgres.Schema.Event
alias Spine.EventStore.Serializer
alias Test.Support.Repo

{:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(Repo, :temporary)
{:ok, _pid} = Repo.start_link()


event = Serializer.serialize(%TestApp.Incremented{})

%Event{
  aggregate_id: "seeded-aggregate-1",
  event_number: 1,
  aggregate_number: 1,
  data: event
}
|> Repo.insert!()

IO.puts "Seeded."
