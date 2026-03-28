defmodule Golfex.Repo.Migrations.CreateScheduledBookings do
  use Ecto.Migration

  def change do
    create table(:scheduled_bookings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :user_club_id, references(:user_clubs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :event_id, references(:events, type: :binary_id, on_delete: :nilify_all)
      add :miclub_event_id, :integer
      add :miclub_group_id, :integer
      add :miclub_row_id, :integer
      add :miclub_member_id, :integer
      add :scheduled_for, :utc_datetime, null: false
      add :status, :string, default: "pending", null: false
      add :oban_job_id, :integer
      add :last_error, :text

      timestamps(type: :utc_datetime)
    end

    create index(:scheduled_bookings, [:user_id, :status])
    create index(:scheduled_bookings, [:status, :scheduled_for])
  end
end
