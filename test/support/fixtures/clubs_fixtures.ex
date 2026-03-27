defmodule Golfex.ClubsFixtures do
  alias Golfex.Clubs

  def club_fixture(attrs \\ %{}) do
    {:ok, club} =
      attrs
      |> Enum.into(%{
        name: "Test Golf Club #{System.unique_integer([:positive])}",
        base_url: "https://testgolf-#{System.unique_integer([:positive])}.com.au"
      })
      |> Clubs.create_club()

    club
  end

  def user_club_fixture(scope, club, attrs \\ %{}) do
    {:ok, user_club} =
      Clubs.add_club_for_user(
        scope,
        club,
        Enum.into(attrs, %{
          member_id: "12345",
          username: "testuser",
          password: "testpass"
        })
      )

    user_club
  end
end
