defmodule GolfexWeb.DashboardLiveTest do
  use GolfexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Golfex.AccountsFixtures
  import Golfex.ClubsFixtures

  describe "Dashboard" do
    test "redirects to login if not authenticated", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "shows clubs for authenticated user", %{conn: conn} do
      user = user_fixture()
      scope = Golfex.Accounts.Scope.for_user(user)
      club = club_fixture(%{name: "The Ridge"})
      _user_club = user_club_fixture(scope, club)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/")

      assert html =~ "Your Clubs"
      assert html =~ "The Ridge"
      assert html =~ "View Events"
    end

    test "shows add a club message when no clubs configured", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/")

      assert html =~ "You haven&#39;t added any golf clubs yet."
      assert html =~ "Add a club"
    end
  end
end
