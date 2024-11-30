defmodule AppWeb.Clubs.IndexLive do
  @moduledoc false
  use AppWeb, :live_view

  def mount(_params, _session, socket) do
    clubs = App.MiClub.list_clubs()
    {:ok, assign(socket, clubs: clubs)}
  end

  def render(assigns) do
    ~H"""
    <header class="wrapper">
      <ul class="breadcrumbs">
        <li><.link navigate="/">Home</.link></li>
        <li>Clubs</li>
      </ul>

      <h1>Clubs</h1>
    </header>

    <section class="region wrapper">
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
