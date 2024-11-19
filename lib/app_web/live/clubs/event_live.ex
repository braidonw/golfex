defmodule AppWeb.Clubs.EventLive do
  @moduledoc false
  use AppWeb, :live_view

  def mount(%{"slug" => slug, "id" => id}, _session, socket) do
    {:ok, club} = App.MiClub.fetch_club_by_slug(slug)
    {:ok, event} = App.MiClub.fetch_event(id)
    event = App.Repo.preload(event, :booking_groups)

    {:ok,
     socket
     |> assign(event: event, club: club)
     |> assign_async(:booking_sections, fn -> fetch_booking_sections(event) end)}
  end

  def render(assigns) do
    ~H"""
    <header class="wrapper">
      <ul class="breadcrumbs">
        <li><.link navigate="/">Home</.link></li>
        <li><.link navigate="/clubs">Clubs</.link></li>
        <li><.link navigate={"/clubs/#{@club.slug}"}><%= @club.name %></.link></li>
        <li><%= @event.name %></li>
      </ul>
      <h1><%= @event.name %></h1>
    </header>

    <section class="region wrapper">
      <h2>Event Details</h2>
      <dl class="card grid event-details">
        <div>
          <dt>Date</dt>
          <dd><%= @event.date %></dd>
        </div>

        <div>
          <dt>Availability</dt>
          <dd><%= @event.availability %></dd>
        </div>

        <div>
          <dt>Status</dt>
          <dd><%= @event.status_code_friendly %></dd>
        </div>

        <div>
          <dt>Open</dt>
          <dd><%= @event.is_open %></dd>
        </div>

        <div>
          <dt>Matchplay</dt>
          <dd><%= @event.is_matchplay %></dd>
        </div>

        <div>
          <dt>Is Ballot</dt>
          <dd><%= @event.is_ballot %></dd>
        </div>

        <div>
          <dt>Is Ballot Open</dt>
          <dd><%= @event.is_ballot_open %></dd>
        </div>

        <div>
          <dt>Has Competition</dt>
          <dd><%= @event.has_competition %></dd>
        </div>

        <div>
          <dt>Is Male</dt>
          <dd><%= @event.is_male %></dd>
        </div>

        <div>
          <dt>Is Female</dt>
          <dd><%= @event.is_female %></dd>
        </div>

        <div>
          <dt>Is Results</dt>
          <dd><%= @event.is_results %></dd>
        </div>

        <div>
          <dt>Is Lottery</dt>
          <dd><%= @event.is_lottery %></dd>
        </div>

        <div>
          <dt>Remote ID</dt>
          <dd><%= @event.remote_id %></dd>
        </div>
      </dl>
    </section>

    <section class="wrapper region">
      <h2>Booking Sections</h2>
      <ul>
        <li :for={section <- @event.booking_groups}>
          <.link class="show-section" navigate={~p"/"}><%= section.name %></.link>
        </li>
      </ul>
    </section>
    """
  end

  defp fetch_booking_sections(event) do
    _remote_id = event.remote_id
    {:ok, %{booking_sections: []}}
  end
end
