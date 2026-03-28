defmodule Golfex.Clubs.UserClub do
  use Ecto.Schema

  import Ecto.Changeset

  alias Golfex.Accounts.User
  alias Golfex.Clubs.{Club, EncryptedBinary}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_clubs" do
    belongs_to :user, User
    belongs_to :club, Club

    field :member_id, EncryptedBinary
    field :username, EncryptedBinary
    field :password, EncryptedBinary

    timestamps(type: :utc_datetime)
  end

  def changeset(user_club, attrs) do
    user_club
    |> cast(attrs, [:member_id, :username, :password, :club_id, :user_id])
    |> validate_required([:member_id, :username, :password, :club_id, :user_id])
    |> unique_constraint([:user_id, :club_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:club_id)
  end
end
