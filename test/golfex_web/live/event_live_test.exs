defmodule GolfexWeb.EventLiveTest do
  use GolfexWeb.ConnCase, async: true

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures
  import Golfex.EventsFixtures
  import Phoenix.LiveViewTest

  describe "Index" do
    test "shows cached events for a club", %{conn: conn} do
      user = user_fixture()
      scope = Golfex.Accounts.Scope.for_user(user)
      club = club_fixture(%{name: "Sunny Links"})
      _user_club = user_club_fixture(scope, club)

      _event =
        event_fixture(club, %{
          title: "Saturday Comp",
          event_date: ~D[2026-04-04],
          availability: 20,
          is_open: true,
          event_status_code_friendly: "Open"
        })

      # Ensure cache is fresh so no MiClub HTTP call is triggered
      _second_event =
        event_fixture(club, %{
          title: "Sunday Medal",
          event_date: ~D[2026-04-05],
          availability: 5,
          is_open: false,
          event_status_code_friendly: "Closed"
        })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/clubs/#{club.id}/events")

      assert html =~ "Events — Sunny Links"
      assert html =~ "Saturday Comp"
      assert html =~ "Sunday Medal"
      assert html =~ "04/04/2026"
      assert html =~ "05/04/2026"
      assert html =~ "20"
      assert html =~ "Yes"
      assert html =~ "No"
    end

    test "has a view link for each event", %{conn: conn} do
      user = user_fixture()
      scope = Golfex.Accounts.Scope.for_user(user)
      club = club_fixture()
      _user_club = user_club_fixture(scope, club)

      event = event_fixture(club, %{title: "Test Event"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/clubs/#{club.id}/events")

      assert html =~ ~p"/clubs/#{club.id}/events/#{event.id}"
    end
  end
end
