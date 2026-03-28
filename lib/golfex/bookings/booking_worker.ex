defmodule Golfex.Bookings.BookingWorker do
  use Oban.Worker, queue: :bookings, max_attempts: 3

  alias Golfex.Bookings
  alias Golfex.Clubs
  alias Golfex.MiClub

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"booking_id" => booking_id}}) do
    booking = Bookings.get_scheduled_booking!(booking_id)

    if booking.status == "cancelled" do
      :ok
    else
      execute_booking(booking)
    end
  end

  defp execute_booking(booking) do
    user_club = Clubs.get_user_club_by_id!(booking.user_club_id)

    Bookings.update_booking_status(booking, "running")

    case MiClub.book(
           user_club,
           booking.miclub_group_id,
           booking.miclub_row_id,
           to_string(booking.miclub_member_id)
         ) do
      :ok ->
        Bookings.update_booking_status(booking, "completed")
        :ok

      {:error, reason} ->
        error_message = if is_binary(reason), do: reason, else: inspect(reason)
        Bookings.update_booking_status(booking, "failed", error_message)
        {:error, error_message}
    end
  end
end
