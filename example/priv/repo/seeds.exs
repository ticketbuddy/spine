alias Example.Repo
alias Spine.EventStore.Postgres.Schema.Event

Repo.insert!(%Event{
  aggregate_id: "seeded-counter-1",
  event_number: 1,
  aggregate_number: 1,
  idempotency_key: "idempo-12345",
  data: "1"
})
