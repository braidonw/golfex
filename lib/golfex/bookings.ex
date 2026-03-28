defmodule Golfex.Bookings do
  import Ecto.Query

  alias Golfex.Accounts.Scope
  alias Golfex.Bookings.{BookingWorker, ScheduledBooking}
  alias Golfex.MiClub
  alias Golfex.Repo

  def book_now(user_club, booking_group_id, row_id, member_id) do
    MiClub.book(user_club, booking_group_id, row_id, member_id)
  end

  def schedule_booking(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:booking, ScheduledBooking.changeset(%ScheduledBooking{}, attrs))
    |> Ecto.Multi.run(:oban_job, fn _repo, %{booking: booking} ->
      job_args = %{booking_id: booking.id}

      job_changeset =
        if booking.scheduled_for do
          BookingWorker.new(job_args, scheduled_at: booking.scheduled_for)
        else
          BookingWorker.new(job_args)
        end

      Oban.insert(job_changeset)
    end)
    |> Ecto.Multi.run(:update_booking, fn _repo, %{booking: booking, oban_job: job} ->
      if job.id do
        booking
        |> Ecto.Changeset.change(%{oban_job_id: job.id})
        |> Repo.update()
      else
        {:ok, booking}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_booking: booking}} -> {:ok, booking}
      {:error, :booking, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def cancel_booking(%ScheduledBooking{} = booking) do
    if ScheduledBooking.cancellable?(booking) do
      if booking.oban_job_id do
        case Repo.get(Oban.Job, booking.oban_job_id) do
          nil ->
            :ok

          job ->
            case Oban.cancel_job(job.id) do
              {:ok, _} -> :ok
              {:error, reason} -> {:error, reason}
              :ok -> :ok
            end
        end
      end

      update_booking_status(booking, "cancelled")
    else
      {:error, :not_cancellable}
    end
  end

  def list_bookings_for_user(%Scope{user: user}) do
    ScheduledBooking
    |> where(user_id: ^user.id)
    |> order_by(desc: :scheduled_for)
    |> preload(:user_club)
    |> Repo.all()
  end

  def get_scheduled_booking!(id) do
    Repo.get!(ScheduledBooking, id)
  end

  def update_booking_status(%ScheduledBooking{} = booking, status, last_error \\ nil) do
    booking
    |> Ecto.Changeset.change(%{status: status, last_error: last_error})
    |> Repo.update()
  end
end
