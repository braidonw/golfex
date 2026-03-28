defmodule GolfexWeb.ClubLiveTest do
  use GolfexWeb.ConnCase, async: true

  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures
  import Phoenix.LiveViewTest

  describe "Index" do
    test "lists user's clubs", %{conn: conn} do
      user = user_fixture()
      scope = Golfex.Accounts.Scope.for_user(user)
      club = club_fixture(%{name: "Riverside Golf Club"})
      _user_club = user_club_fixture(scope, club)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/clubs")

      assert html =~ "Riverside Golf Club"
      assert html =~ club.base_url
    end

    test "creates a new club association via the form", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/clubs/new")

      result =
        lv
        |> form("#club-form",
          club: %{
            name: "New Test Club",
            base_url: "https://newtestclub.com.au",
            member_id: "99999",
            username: "newuser",
            password: "newpass"
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/clubs"}}} = result

      # Follow redirect and verify club appears
      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/clubs")

      assert html =~ "New Test Club"
    end

    test "removes a club association", %{conn: conn} do
      user = user_fixture()
      scope = Golfex.Accounts.Scope.for_user(user)
      club = club_fixture(%{name: "Club To Remove"})
      user_club = user_club_fixture(scope, club)

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/clubs")

      assert html =~ "Club To Remove"

      lv
      |> element(~s([phx-click="delete"][phx-value-id="#{user_club.id}"]))
      |> render_click()

      refute render(lv) =~ "Club To Remove"
    end
  end
end
