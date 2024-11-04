defmodule App.MiClub do
  @moduledoc false

  alias App.MiClub.Club
  alias App.MiClub.Query
  alias App.Repo

  def list_clubs do
    Repo.all(Club)
  end

  def get_club!(slug) do
    Repo.get_by(Club, slug: slug) || raise "Club not found"
  end

  def list_club_events(slug) do
    Query.event_base() |> Query.by_club(slug) |> Repo.all()
  end
end
