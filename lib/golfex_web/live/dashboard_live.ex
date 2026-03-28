defmodule GolfexWeb.DashboardLive do
  use GolfexWeb, :live_view

  alias Golfex.Clubs

  def mount(_params, _session, socket) do
    user_clubs = Clubs.list_clubs_for_user(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:user_clubs, user_clubs)}
  end

  def render(assigns) do
    ~H"""
    <div class="flow">
      <h1>Dashboard</h1>

      <%= if @user_clubs == [] do %>
        <p>You haven't added any golf clubs yet.</p>
        <.button navigate={~p"/clubs/new"}>Add a club</.button>
      <% else %>
        <h2>Your Clubs</h2>
        <div class="grid">
          <div :for={uc <- @user_clubs} class="sc-card">
            <h3>{uc.club.name}</h3>
            <.link class="button" navigate={~p"/clubs/#{uc.club_id}/events"} class="sc-button">
              View Events
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
