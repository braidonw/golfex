defmodule Golfex.Clubs.Club do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "clubs" do
    field :name, :string
    field :base_url, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(club, attrs) do
    club
    |> cast(attrs, [:name, :base_url])
    |> validate_required([:name, :base_url])
    |> validate_format(:base_url, ~r/^https?:\/\//, message: "must start with http:// or https://")
  end
end
