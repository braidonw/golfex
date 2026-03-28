defmodule Golfex.Clubs do
  import Ecto.Query

  alias Golfex.Accounts.Scope
  alias Golfex.Clubs.{Club, UserClub}
  alias Golfex.Repo

  def list_clubs do
    Repo.all(Club)
  end

  def get_club!(id) do
    Repo.get!(Club, id)
  end

  def create_club(attrs) do
    %Club{}
    |> Club.changeset(attrs)
    |> Repo.insert()
  end

  def list_clubs_for_user(%Scope{user: user}) do
    UserClub
    |> where(user_id: ^user.id)
    |> preload(:club)
    |> Repo.all()
  end

  def get_user_club!(%Scope{user: user}, id) do
    UserClub
    |> where(user_id: ^user.id, id: ^id)
    |> preload(:club)
    |> Repo.one!()
  end

  def get_user_club_by_club_id!(%Scope{user: user}, club_id) do
    UserClub
    |> where(user_id: ^user.id, club_id: ^club_id)
    |> preload(:club)
    |> Repo.one!()
  end

  def get_user_club_by_id!(id) do
    UserClub
    |> preload(:club)
    |> Repo.get!(id)
  end

  def add_club_for_user(%Scope{user: user}, %Club{} = club, attrs) do
    %UserClub{}
    |> UserClub.changeset(Map.merge(attrs, %{user_id: user.id, club_id: club.id}))
    |> Repo.insert()
  end

  def update_user_club(%UserClub{} = user_club, attrs) do
    user_club
    |> UserClub.changeset(attrs)
    |> Repo.update()
  end

  def remove_club_for_user(%Scope{user: user}, user_club_id) do
    UserClub
    |> where(user_id: ^user.id, id: ^user_club_id)
    |> Repo.one!()
    |> Repo.delete()
  end

  def change_user_club(%UserClub{} = user_club, attrs \\ %{}) do
    UserClub.changeset(user_club, attrs)
  end
end
