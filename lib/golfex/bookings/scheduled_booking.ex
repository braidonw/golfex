defmodule Golfex.Bookings.ScheduledBooking do
  use Ecto.Schema
  import Ecto.Changeset

  alias Golfex.Accounts.User
  alias Golfex.Clubs.UserClub
  alias Golfex.Events.Event

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "scheduled_bookings" do
    belongs_to :user, User
    belongs_to :user_club, UserClub
    belongs_to :event, Event

    field :miclub_event_id, :integer
    field :miclub_group_id, :integer
    field :miclub_row_id, :integer
    field :miclub_member_id, :integer
    field :scheduled_for, :utc_datetime
    field :status, :string, default: "pending"
    field :oban_job_id, :integer
    field :last_error, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [
      :user_id,
      :user_club_id,
      :event_id,
      :miclub_event_id,
      :miclub_group_id,
      :miclub_row_id,
      :miclub_member_id,
      :scheduled_for,
      :status,
      :oban_job_id,
      :last_error
    ])
    |> validate_required([
      :user_id,
      :user_club_id,
      :miclub_group_id,
      :miclub_row_id,
      :miclub_member_id,
      :scheduled_for
    ])
    |> validate_inclusion(:status, ~w(pending running completed failed cancelled))
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:user_club_id)
    |> foreign_key_constraint(:event_id)
  end

  def cancellable?(%__MODULE__{status: "pending"}), do: true
  def cancellable?(%__MODULE__{}), do: false
end
