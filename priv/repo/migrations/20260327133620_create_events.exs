defmodule Golfex.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :club_id, references(:clubs, type: :binary_id, on_delete: :delete_all), null: false
      add :miclub_event_id, :integer, null: false
      add :title, :string, null: false
      add :event_date, :date, null: false
      add :event_status_code, :integer
      add :event_status_code_friendly, :string
      add :availability, :integer, null: false
      add :is_open, :boolean, default: false, null: false
      add :is_ballot, :boolean, default: false, null: false
      add :is_ballot_open, :boolean, default: false, null: false
      add :is_lottery, :boolean
      add :has_competition, :boolean
      add :is_matchplay, :boolean, default: false, null: false
      add :is_results, :boolean, default: false, null: false
      add :event_type_code, :integer
      add :event_category_code, :integer
      add :event_time_code_friendly, :string
      add :auto_open_date_time_display, :string
      add :cached_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:events, [:club_id, :miclub_event_id])
  end
end
