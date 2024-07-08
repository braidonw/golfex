defmodule App.MiClub.Club do
  @moduledoc false
  use App.Schema

  alias App.MiClub.BookingEvent

  schema "miclub_clubs" do
    field :name, :string
    field :website, :string
    field :slug, :string

    has_many :events, BookingEvent

    timestamps()
  end

  def changeset(club, attrs) do
    club
    |> cast(attrs, [:name, :website, :slug])
    |> validate_required([:name, :website, :slug])
    |> unique_constraint(:slug)
  end
end
