defmodule GolfexWeb.BookingGroupLiveTest do
  use GolfexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures
  import Golfex.EventsFixtures

  describe "Show" do
    test "renders loading state on mount", %{conn: conn} do
      user = user_fixture()
      scope = Golfex.Accounts.Scope.for_user(user)
      club = club_fixture(%{name: "Test Club"})
      _user_club = user_club_fixture(scope, club)

      event =
        event_fixture(club, %{
          title: "Saturday Comp",
          event_date: ~D[2026-04-04]
        })

      # Stub the MiClub HTTP call that will be triggered by :load_group_detail
      Req.Test.expect(Golfex.MiClub, fn conn ->
        Req.Test.json(conn, %{})
      end)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/clubs/#{club.id}/events/#{event.id}/groups/1")

      assert html =~ "Loading group details"
    end
  end
end
