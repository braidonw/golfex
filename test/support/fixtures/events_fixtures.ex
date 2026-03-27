defmodule Golfex.EventsFixtures do
  alias Golfex.Events

  def event_fixture(club, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    miclub_events = [
      Map.merge(
        %{
          id: attrs[:miclub_event_id] || unique,
          title: attrs[:title] || "Test Event #{unique}",
          event_date: attrs[:event_date] || Date.utc_today(),
          availability: attrs[:availability] || 10,
          is_open: attrs[:is_open] || true
        },
        Map.drop(attrs, [:miclub_event_id, :title, :event_date, :availability, :is_open])
      )
    ]

    {1, _} = Events.upsert_events(club, miclub_events)

    Events.list_events_for_club(club) |> List.last()
  end
end
