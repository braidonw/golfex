defmodule App.MiClub.BookingSection do
  @moduledoc false
  use App.Schema

  schema "miclub_booking_sections" do
    field :remote_id, :string
    field :name, :string
    field :index, :integer
    field :active, :boolean

    belongs_to :booking_event, App.MiClub.BookingEvent
    has_many :booking_groups, App.MiClub.BookingGroup

    timestamps()
  end

  def changeset(section, attrs) do
    section
    |> cast(attrs, [:remote_id, :booking_event_id, :name, :index, :active])
    |> validate_required([:remote_id, :booking_event_id])
    |> unique_constraint(:remote_id)
    |> foreign_key_constraint(:booking_event_id)
  end
end
