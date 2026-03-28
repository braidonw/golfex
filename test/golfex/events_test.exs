defmodule Golfex.EventsTest do
  use Golfex.DataCase, async: true

  alias Golfex.Events

  import Golfex.ClubsFixtures
  import Golfex.EventsFixtures

  setup do
    club = club_fixture()
    %{club: club}
  end

  describe "upsert_events/2" do
    test "inserts new events", %{club: club} do
      miclub_events = [
        %{
          id: 100,
          title: "Saturday Comp",
          event_date: ~D[2026-04-01],
          availability: 20,
          is_open: true
        },
        %{
          id: 101,
          title: "Sunday Comp",
          event_date: ~D[2026-04-02],
          availability: 15,
          is_open: false
        }
      ]

      assert {2, _} = Events.upsert_events(club, miclub_events)

      events = Events.list_events_for_club(club)
      assert length(events) == 2
      assert Enum.map(events, & &1.title) == ["Saturday Comp", "Sunday Comp"]
    end

    test "updates existing events on re-sync", %{club: club} do
      miclub_events = [
        %{
          id: 200,
          title: "Original Title",
          event_date: ~D[2026-04-01],
          availability: 10,
          is_open: false
        }
      ]

      assert {1, _} = Events.upsert_events(club, miclub_events)

      updated_events = [
        %{
          id: 200,
          title: "Updated Title",
          event_date: ~D[2026-04-01],
          availability: 5,
          is_open: true
        }
      ]

      assert {1, _} = Events.upsert_events(club, updated_events)

      events = Events.list_events_for_club(club)
      assert length(events) == 1
      assert hd(events).title == "Updated Title"
      assert hd(events).availability == 5
      assert hd(events).is_open == true
    end
  end

  describe "list_events_for_club/1" do
    test "returns events ordered by date", %{club: club} do
      event_fixture(club, %{miclub_event_id: 1, title: "Later", event_date: ~D[2026-05-01]})
      event_fixture(club, %{miclub_event_id: 2, title: "Earlier", event_date: ~D[2026-03-01]})
      event_fixture(club, %{miclub_event_id: 3, title: "Middle", event_date: ~D[2026-04-01]})

      events = Events.list_events_for_club(club)
      assert Enum.map(events, & &1.title) == ["Earlier", "Middle", "Later"]
    end
  end

  describe "cache_stale?/1" do
    test "returns true when no events exist", %{club: club} do
      assert Events.cache_stale?(club)
    end

    test "returns false when events cached recently", %{club: club} do
      event_fixture(club)
      refute Events.cache_stale?(club)
    end

    test "returns true when events older than 12 hours", %{club: club} do
      event = event_fixture(club)
      Events.invalidate_event(event)
      assert Events.cache_stale?(club)
    end
  end

  describe "invalidate_events/1" do
    test "marks all events for a club as stale", %{club: club} do
      event_fixture(club)
      refute Events.cache_stale?(club)

      Events.invalidate_events(club)
      assert Events.cache_stale?(club)
    end
  end

  describe "invalidate_event/1" do
    test "marks a specific event as stale", %{club: club} do
      event = event_fixture(club)
      refute Events.cache_stale?(club)

      {:ok, updated_event} = Events.invalidate_event(event)
      assert DateTime.diff(DateTime.utc_now(), updated_event.cached_at, :hour) >= 13

      assert Events.cache_stale?(club)
    end
  end
end
