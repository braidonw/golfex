defmodule Golfex.EventsFixtures do
  alias Golfex.Events
  alias Golfex.Events.Event
  alias Golfex.Repo

  def event_fixture(club, attrs \\ %{}) do
    unique = System.unique_integer([:positive])
    miclub_event_id = attrs[:miclub_event_id] || unique

    miclub_events = [
      Map.merge(
        %{
          id: miclub_event_id,
          title: attrs[:title] || "Test Event #{unique}",
          event_date: attrs[:event_date] || Date.utc_today(),
          availability: attrs[:availability] || 10,
          is_open: Map.get(attrs, :is_open, true)
        },
        Map.drop(attrs, [:miclub_event_id, :title, :event_date, :availability, :is_open])
      )
    ]

    {1, _} = Events.upsert_events(club, miclub_events)

    Repo.get_by!(Event, club_id: club.id, miclub_event_id: miclub_event_id)
  end
end
