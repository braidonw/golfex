defmodule AppWeb.DashboardLive do
  @moduledoc false
  use AppWeb, :live_view

  def mount(_params, _session, socket) do
    clubs = App.MiClub.list_clubs()
    {:ok, assign(socket, clubs: clubs)}
  end

  def render(assigns) do
    ~H"""
    <header class="wrapper">
      <h1>GolfEx</h1>
    </header>

    <section class="wrapper region">
      <h2>Clubs</h2>

      <ul>
        <%= for club <- @clubs do %>
          <li><.link navigate={~p"/clubs/#{club.slug}/"}><%= club.name %></.link></li>
        <% end %>
      </ul>
    </section>
    """
  end
end
