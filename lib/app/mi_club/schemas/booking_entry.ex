defmodule App.MiClub.BookingEntry do
  @moduledoc false
  use App.Schema

  schema "miclub_booking_entries" do
    field :remote_id, :string
    field :index, :integer
    field :person_name, :string
    field :membership_number, :string
    field :gender, :string
    field :handicap, :float
    field :golf_link_no, :string

    belongs_to :booking_group, App.MiClub.BookingGroup

    timestamps()
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :remote_id,
      :index,
      :person_name,
      :membership_number,
      :gender,
      :handicap,
      :golf_link_no,
      :booking_group_id
    ])
    |> validate_required([:remote_id, :index, :person_name, :booking_group_id])
    |> unique_constraint(:remote_id)
    |> foreign_key_constraint(:booking_group_id)
  end
end
