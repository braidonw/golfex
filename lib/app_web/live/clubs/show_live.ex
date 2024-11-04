defmodule AppWeb.Clubs.ShowLive do
  @moduledoc false
  use AppWeb, :live_view

  def mount(%{"slug" => slug}, _session, socket) do
    club = App.MiClub.get_club!(slug)
    events = App.MiClub.list_club_events(club.slug)
    {:ok, assign(socket, club: club, events: events)}
  end

  def render(assigns) do
    ~H"""
    <header>
      <ul class="breadcrumbs">
        <li><.link navigate="/">Home</.link></li>
        <li><.link navigate="/clubs">Clubs</.link></li>
        <li><%= @club.name %></li>
      </ul>
      <h1><%= @club.name %></h1>
    </header>

    <section>
      <h2>Events</h2>

      <ul>
        <%= for event <- @events do %>
          <li>
            <.link navigate={~p"/clubs/#{@club.slug}/events/#{event.id}"}><%= event.name %></.link>
          </li>
        <% end %>
      </ul>
    </section>
    """
  end
end
