defmodule App.MiClub.BookingGroup do
  @moduledoc false
  use App.Schema

  schema "miclub_booking_groups" do
    field :remote_id, :string
    field :active, :string
    field :name, :string
    field :time, :time
    field :status_code, :string
    field :require_gender, :boolean
    field :require_golf_link, :boolean
    field :require_handicap, :boolean
    field :require_home_club, :boolean
    field :visitor_accepted, :boolean
    field :member_accepted, :boolean
    field :public_member_accepted, :boolean
    field :nine_holes, :boolean
    field :eighteen_holes, :boolean

    belongs_to :booking_section, App.MiClub.BookingSection
    has_many :booking_entries, App.MiClub.BookingEntry

    timestamps()
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :remote_id,
      :active,
      :name,
      :time,
      :status_code,
      :require_gender,
      :require_golf_link,
      :require_handicap,
      :require_home_club,
      :visitor_accepted,
      :member_accepted,
      :public_member_accepted,
      :nine_holes,
      :eighteen_holes,
      :booking_section_id
    ])
    |> validate_required([
      :remote_id,
      :booking_section_id
    ])
    |> unique_constraint(:remote_id)
    |> foreign_key_constraint(:booking_section_id)
  end
end
