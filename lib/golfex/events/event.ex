defmodule Golfex.Events.Event do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "events" do
    belongs_to :club, Golfex.Clubs.Club

    field :miclub_event_id, :integer
    field :title, :string
    field :event_date, :date
    field :event_status_code, :integer
    field :event_status_code_friendly, :string
    field :availability, :integer
    field :is_open, :boolean, default: false
    field :is_ballot, :boolean, default: false
    field :is_ballot_open, :boolean, default: false
    field :is_lottery, :boolean
    field :has_competition, :boolean
    field :is_matchplay, :boolean, default: false
    field :is_results, :boolean, default: false
    field :event_type_code, :integer
    field :event_category_code, :integer
    field :event_time_code_friendly, :string
    field :auto_open_date_time_display, :string
    field :cached_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :club_id,
      :miclub_event_id,
      :title,
      :event_date,
      :event_status_code,
      :event_status_code_friendly,
      :availability,
      :is_open,
      :is_ballot,
      :is_ballot_open,
      :is_lottery,
      :has_competition,
      :is_matchplay,
      :is_results,
      :event_type_code,
      :event_category_code,
      :event_time_code_friendly,
      :auto_open_date_time_display,
      :cached_at
    ])
    |> validate_required([
      :club_id,
      :miclub_event_id,
      :title,
      :event_date,
      :availability,
      :cached_at
    ])
    |> unique_constraint([:club_id, :miclub_event_id])
  end
end
