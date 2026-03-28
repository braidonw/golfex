defmodule Golfex.Bookings.BookingWorkerTest do
  use Golfex.DataCase, async: true
  use Oban.Testing, repo: Golfex.Repo

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures

  alias Golfex.Bookings
  alias Golfex.Bookings.BookingWorker

  describe "perform/1" do
    test "executes booking and updates status to completed" do
      scope = user_scope_fixture()
      club = club_fixture()
      user_club = user_club_fixture(scope, club)

      Req.Test.stub(Golfex.MiClub.Client, fn conn ->
        case conn.request_path do
          "/security/login.msp" -> Req.Test.json(conn, %{})
          "/members/Ajax" -> Req.Test.text(conn, "<Success/>")
        end
      end)

      # Insert booking directly (bypass schedule_booking to avoid inline execution)
      {:ok, booking} =
        %Golfex.Bookings.ScheduledBooking{}
        |> Golfex.Bookings.ScheduledBooking.changeset(%{
          user_id: scope.user.id,
          user_club_id: user_club.id,
          miclub_group_id: 456,
          miclub_row_id: 789,
          miclub_member_id: 12345,
          scheduled_for: DateTime.utc_now(:second)
        })
        |> Repo.insert()

      assert :ok = perform_job(BookingWorker, %{booking_id: booking.id})

      updated = Bookings.get_scheduled_booking!(booking.id)
      assert updated.status == "completed"
    end
  end
end
