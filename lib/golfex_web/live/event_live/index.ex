defmodule GolfexWeb.EventLive.Index do
  use GolfexWeb, :live_view

  alias Golfex.Clubs
  alias Golfex.Events

  @impl true
  def mount(%{"club_id" => club_id}, _session, socket) do
    user_club = Clubs.get_user_club_by_club_id!(socket.assigns.current_scope, club_id)
    club = user_club.club
    events = Events.list_events_for_club(club)

    socket =
      socket
      |> assign(:page_title, "Events — #{club.name}")
      |> assign(:user_club, user_club)
      |> assign(:club, club)
      |> assign(:events, events)
      |> assign(:loading, false)

    if Events.cache_stale?(club) do
      send(self(), :sync_events)
      {:ok, assign(socket, :loading, true)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    send(self(), :sync_events)
    {:noreply, assign(socket, :loading, true)}
  end

  @impl true
  def handle_info(:sync_events, socket) do
    %{user_club: user_club, club: club} = socket.assigns

    socket =
      case Golfex.MiClub.list_events(user_club) do
        {:ok, miclub_events} ->
          Events.upsert_events(club, miclub_events)
          events = Events.list_events_for_club(club)

          socket
          |> assign(:events, events)
          |> assign(:loading, false)
          |> put_flash(:info, "Events synced successfully.")

        {:error, _reason} ->
          socket
          |> assign(:loading, false)
          |> put_flash(:error, "Failed to sync events.")
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flow">
      <.header>
        Events — {@club.name}
        <:actions>
          <.button phx-click="refresh" disabled={@loading}>
            <%= if @loading, do: "Syncing…", else: "Refresh" %>
          </.button>
        </:actions>
      </.header>

      <.link navigate={~p"/clubs"}>← Back to clubs</.link>

      <%= if @loading and @events == [] do %>
        <p>Loading events…</p>
      <% else %>
        <.table id="events" rows={@events}>
          <:col :let={event} label="Date">
            {Calendar.strftime(event.event_date, "%d/%m/%Y")}
          </:col>
          <:col :let={event} label="Title">{event.title}</:col>
          <:col :let={event} label="Status">{event.event_status_code_friendly}</:col>
          <:col :let={event} label="Availability">{event.availability}</:col>
          <:col :let={event} label="Open?">
            <%= if event.is_open, do: "Yes", else: "No" %>
          </:col>
          <:action :let={event}>
            <.link navigate={~p"/clubs/#{@club.id}/events/#{event.id}"}>View</.link>
          </:action>
        </.table>
      <% end %>
    </div>
    """
  end
end
