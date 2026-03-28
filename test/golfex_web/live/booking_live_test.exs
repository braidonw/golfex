defmodule GolfexWeb.BookingLiveTest do
  use GolfexWeb.ConnCase, async: true

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures
  import Phoenix.LiveViewTest

  alias Golfex.Bookings.ScheduledBooking

  describe "index" do
    test "shows scheduled bookings for user", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      club = club_fixture()
      user_club = user_club_fixture(scope, club)

      # Create a booking directly
      %ScheduledBooking{}
      |> ScheduledBooking.changeset(%{
        user_id: user.id,
        user_club_id: user_club.id,
        miclub_event_id: 100,
        miclub_group_id: 10,
        miclub_row_id: 200,
        miclub_member_id: 12345,
        scheduled_for: DateTime.add(DateTime.utc_now(), 3600, :second),
        status: "pending"
      })
      |> Golfex.Repo.insert!()

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/bookings")

      assert html =~ "pending"
    end
  end
end
