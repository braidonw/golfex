defmodule Golfex.ClubsTest do
  use Golfex.DataCase, async: true

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures

  alias Golfex.Clubs
  alias Golfex.Clubs.{Club, UserClub}

  describe "clubs" do
    test "create_club/1 with valid data creates a club" do
      attrs = %{name: "The Ridge Golf Club", base_url: "https://theridgegolf.com.au"}
      assert {:ok, %Club{} = club} = Clubs.create_club(attrs)
      assert club.name == "The Ridge Golf Club"
      assert club.base_url == "https://theridgegolf.com.au"
    end

    test "create_club/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Clubs.create_club(%{name: nil})
    end

    test "list_clubs/0 returns all clubs" do
      club = club_fixture()
      assert Clubs.list_clubs() == [club]
    end

    test "get_club!/1 returns the club" do
      club = club_fixture()
      assert Clubs.get_club!(club.id) == club
    end
  end

  describe "user_clubs" do
    test "add_club_for_user/3 associates a user with a club and encrypts credentials" do
      scope = user_scope_fixture()
      club = club_fixture()

      attrs = %{
        member_id: "12345",
        username: "testuser",
        password: "testpass"
      }

      assert {:ok, %UserClub{} = user_club} = Clubs.add_club_for_user(scope, club, attrs)
      assert user_club.club_id == club.id
      assert user_club.member_id == "12345"
      assert user_club.username == "testuser"
      assert user_club.password == "testpass"
    end

    test "add_club_for_user/3 enforces unique user+club" do
      scope = user_scope_fixture()
      club = club_fixture()
      attrs = %{member_id: "12345", username: "user", password: "pass"}

      assert {:ok, _} = Clubs.add_club_for_user(scope, club, attrs)
      assert {:error, %Ecto.Changeset{}} = Clubs.add_club_for_user(scope, club, attrs)
    end

    test "list_clubs_for_user/1 returns only that user's clubs" do
      scope = user_scope_fixture()
      club = club_fixture()
      _other_club = club_fixture()

      attrs = %{member_id: "12345", username: "user", password: "pass"}
      {:ok, _} = Clubs.add_club_for_user(scope, club, attrs)

      clubs = Clubs.list_clubs_for_user(scope)
      assert length(clubs) == 1
      assert hd(clubs).club.id == club.id
    end

    test "get_user_club!/2 returns the user_club with club preloaded" do
      scope = user_scope_fixture()
      club = club_fixture()
      attrs = %{member_id: "12345", username: "user", password: "pass"}
      {:ok, user_club} = Clubs.add_club_for_user(scope, club, attrs)

      fetched = Clubs.get_user_club!(scope, user_club.id)
      assert fetched.id == user_club.id
      assert fetched.club.id == club.id
    end

    test "remove_club_for_user/2 deletes the association" do
      scope = user_scope_fixture()
      club = club_fixture()
      attrs = %{member_id: "12345", username: "user", password: "pass"}
      {:ok, user_club} = Clubs.add_club_for_user(scope, club, attrs)

      assert {:ok, _} = Clubs.remove_club_for_user(scope, user_club.id)
      assert Clubs.list_clubs_for_user(scope) == []
    end

    test "update_user_club/2 updates credentials" do
      scope = user_scope_fixture()
      club = club_fixture()
      attrs = %{member_id: "12345", username: "user", password: "pass"}
      {:ok, user_club} = Clubs.add_club_for_user(scope, club, attrs)

      assert {:ok, updated} = Clubs.update_user_club(user_club, %{username: "newuser"})
      assert updated.username == "newuser"
    end
  end
end
