defmodule App.Repo.Migrations.AddMiclubEntries do
  use Ecto.Migration

  def change do
    create table(:miclub_clubs) do
      add :name, :string, null: false
      add :website, :string, null: false
      add :slug, :string, null: false

      timestamps()
    end

    create unique_index(:miclub_clubs, [:slug])

    create table(:miclub_booking_events) do
      add :remote_id, :string, null: false
      add :club_id, references(:miclub_clubs), null: false
      add :name, :string, null: false
      add :date, :date, null: false
      add :last_modified, :utc_datetime, null: true
      add :last_modified_by_id, :string, null: true

      add :status_code, :string, null: true
      add :status_code_friendly, :string, null: true
      add :booking_resource_id, :integer, null: true
      add :redirect_url, :string, null: true
      add :first_manual_upload_results, :string, null: true
      add :is_lottery, :boolean, null: true
      add :can_open_event, :boolean, null: true
      add :has_competition, :boolean, null: true
      add :matchplay_id, :integer, null: true
      add :event_type_code, :integer, null: true
      add :event_category_code, :integer, null: true
      add :event_time_code_friendly, :string, null: true
      add :booking_note_action, :string, null: true
      add :auto_open_date_time_display, :string, null: true
      add :availability, :integer, null: false
      add :is_ballot, :boolean, null: false
      add :is_ballot_open, :boolean, null: false
      add :is_results, :boolean, null: false
      add :is_open, :boolean, null: false
      add :is_female, :boolean, null: false
      add :is_male, :boolean, null: false
      add :is_matchplay, :boolean, null: false

      timestamps()
    end

    create unique_index(:miclub_booking_events, [:remote_id])

    create table(:miclub_booking_sections) do
      add :booking_event_id, references(:miclub_booking_events), null: false
      add :remote_id, :string, null: false

      timestamps()
    end

    create unique_index(:miclub_booking_sections, [:remote_id])

    create table(:miclub_booking_groups) do
      add :booking_section_id, references(:miclub_booking_sections), null: false
      add :remote_id, :string, null: false
      add :active, :string, null: true
      add :name, :string, null: true
      add :time, :time, null: true
      add :status_code, :string, null: true
      add :require_gender, :boolean, null: true
      add :require_golf_link, :boolean, null: true
      add :require_handicap, :boolean, null: true
      add :require_home_club, :boolean, null: true
      add :visitor_accepted, :boolean, null: true
      add :member_accepted, :boolean, null: true
      add :public_member_accepted, :boolean, null: true
      add :nine_holes, :boolean, null: true
      add :eighteen_holes, :boolean, null: true

      timestamps()
    end

    create unique_index(:miclub_booking_groups, [:remote_id])

    create table(:miclub_booking_entries) do
      add :booking_group_id, references(:miclub_booking_groups), null: false
      add :remote_id, :string, null: false
      add :index, :integer, null: true
      add :person_name, :string, null: true
      add :membership_number, :string, null: true
      add :gender, :string, null: true
      add :handicap, :float, null: true
      add :golf_link_no, :string, null: true

      timestamps()
    end

    create unique_index(:miclub_booking_entries, [:remote_id])
  end
end
