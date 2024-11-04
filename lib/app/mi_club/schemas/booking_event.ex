defmodule App.MiClub.BookingEvent do
  @moduledoc false

  use App.Schema

  schema "miclub_booking_events" do
    belongs_to :club, App.MiClub.Club
    field :remote_id, :string
    field :name, :string
    field :date, :date
    field :last_modified, :utc_datetime
    field :last_modified_by_id, :string

    field :status_code, :string
    field :status_code_friendly, :string
    field :booking_resource_id, :integer
    field :redirect_url, :string
    field :first_manual_upload_results, :string
    field :is_lottery, :boolean
    field :can_open_event, :boolean
    field :has_competition, :boolean
    field :matchplay_id, :integer
    field :event_type_code, :integer
    field :event_category_code, :integer
    field :event_time_code_friendly, :string
    field :booking_note_action, :string
    field :auto_open_date_time_display, :string
    field :availability, :integer
    field :is_ballot, :boolean
    field :is_ballot_open, :boolean
    field :is_results, :boolean
    field :is_open, :boolean
    field :is_female, :boolean
    field :is_male, :boolean
    field :is_matchplay, :boolean

    has_many :booking_sections, App.MiClub.BookingSection

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :remote_id,
      :club_id,
      :name,
      :date,
      :last_modified,
      :last_modified_by_id,
      :status_code,
      :status_code_friendly,
      :booking_resource_id,
      :redirect_url,
      :first_manual_upload_results,
      :is_lottery,
      :can_open_event,
      :has_competition,
      :matchplay_id,
      :event_type_code,
      :event_category_code,
      :event_time_code_friendly,
      :booking_note_action,
      :auto_open_date_time_display,
      :availability,
      :is_ballot,
      :is_ballot_open,
      :is_results,
      :is_open,
      :is_female,
      :is_male,
      :is_matchplay
    ])
    |> validate_required([
      :remote_id,
      :name,
      :date,
      :availability,
      :is_ballot,
      :is_ballot_open,
      :is_results,
      :is_open,
      :is_female,
      :is_male,
      :is_matchplay
    ])
    |> unique_constraint(:remote_id)
    |> foreign_key_constraint(:club_id)
  end
end
