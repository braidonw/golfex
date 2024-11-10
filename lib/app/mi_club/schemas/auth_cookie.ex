defmodule App.MiClub.AuthCookie do
  @moduledoc false

  use App.Schema

  schema "mi_club_cookies" do
    field :cookie, :string
    field :expires_at, :utc_datetime
    belongs_to :club, App.MiClub.Club

    timestamps()
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:cookie, :expires_at, :club_id])
    |> validate_required([:cookie, :expires_at, :club_id])
    |> foreign_key_constraint(:club_id)
  end
end
