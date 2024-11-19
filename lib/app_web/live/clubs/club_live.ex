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
    <header class="wrapper">
      <ul class="breadcrumbs">
        <li><.link navigate="/">Home</.link></li>
        <li><.link navigate="/clubs">Clubs</.link></li>
        <li><%= @club.name %></li>
      </ul>
      <h1><%= @club.name %></h1>
    </header>

    <section class="wrapper">
      <h2>Events</h2>

      <ul class="flow">
        <li :for={event <- @events}>
          <.link class="show-event" navigate={~p"/clubs/#{@club.slug}/events/#{event.id}"}>
            <div class="card">
              <h3><%= event.name %></h3>
              <dl class="cluster">
                <div>
                  <dt>Date</dt>
                  <dd><%= event.date %></dd>
                </div>

                <div>
                  <dt>Status</dt>
                  <dd><%= event.status_code_friendly %></dd>
                </div>

                <div>
                  <dt>Availability</dt>
                  <dd><%= event.availability %></dd>
                </div>
              </dl>
            </div>
          </.link>
        </li>
      </ul>

      <table>
        <thead>
          <tr>
            <th scope="col">Date</th>
            <th scope="col">Name</th>
            <th scope="col">Time</th>
          </tr>
        </thead>

        <tbody>
          <tr :for={event <- @events}>
            <td><%= event.date %></td>
            <td>
              <.link navigate={~p"/clubs/#{@club.slug}/events/#{event.id}"}><%= event.name %></.link>
            </td>
            <td><%= event.event_time_code_friendly %></td>
          </tr>
        </tbody>
      </table>
    </section>
    """
  end
end
