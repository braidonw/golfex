defmodule Golfex.Bookings.BookingWorker do
  use Oban.Worker, queue: :bookings, max_attempts: 3

  alias Golfex.Bookings
  alias Golfex.Clubs
  alias Golfex.MiClub
  alias Golfex.MiClub.{BookingEvent, BookingGroup}

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

    case resolve_row_id(booking, user_club) do
      {:ok, row_id} ->
        case MiClub.book(
               user_club,
               booking.miclub_group_id,
               row_id,
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

      {:error, reason} ->
        Bookings.update_booking_status(booking, "failed", reason)
        {:error, reason}
    end
  end

  # If miclub_row_id is already set (e.g. from book_now), use it directly.
  # Otherwise, fetch the event and find the first empty slot in the group.
  defp resolve_row_id(%{miclub_row_id: row_id}, _user_club) when not is_nil(row_id) do
    {:ok, row_id}
  end

  defp resolve_row_id(booking, user_club) do
    with {:ok, booking_event} <- MiClub.get_event(user_club, booking.miclub_event_id),
         {group, _section} <- BookingEvent.get_booking_group(booking_event, booking.miclub_group_id),
         {:ok, entry} <- BookingGroup.first_empty_entry(group) do
      {:ok, entry.id}
    else
      nil -> {:error, "Booking group not found"}
      :none -> {:error, "No empty slots available in this group"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
