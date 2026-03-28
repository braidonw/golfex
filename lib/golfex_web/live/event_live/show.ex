defmodule GolfexWeb.EventLive.Show do
  use GolfexWeb, :live_view

  alias Golfex.Clubs
  alias Golfex.Events
  alias Golfex.MiClub.BookingGroup

  @impl true
  def mount(%{"club_id" => club_id, "event_id" => event_id}, _session, socket) do
    user_club = Clubs.get_user_club_by_club_id!(socket.assigns.current_scope, club_id)
    event = Events.get_event!(event_id)

    send(self(), :load_event_detail)

    {:ok,
     socket
     |> assign(:page_title, event.title)
     |> assign(:user_club, user_club)
     |> assign(:club, user_club.club)
     |> assign(:event, event)
     |> assign(:booking_event, nil)
     |> assign(:loading, true)}
  end

  @impl true
  def handle_info(:load_event_detail, socket) do
    %{user_club: user_club, event: event} = socket.assigns

    socket =
      case Golfex.MiClub.get_event(user_club, event.miclub_event_id) do
        {:ok, booking_event} ->
          socket
          |> assign(:booking_event, booking_event)
          |> assign(:loading, false)

        {:error, _reason} ->
          socket
          |> assign(:loading, false)
          |> put_flash(:error, "Failed to load event details.")
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flow">
      <.link navigate={~p"/clubs/#{@club.id}/events"}>← Back to events</.link>

      <.header>
        {@event.title}
        <:subtitle>
          {Calendar.strftime(@event.event_date, "%d/%m/%Y")}
        </:subtitle>
      </.header>

      <%= if @loading do %>
        <p>Loading event details…</p>
      <% else %>
        <%= if @booking_event do %>
          <div :for={section <- @booking_event.booking_sections} class="flow">
            <h2>{section.name}</h2>

            <.table
              id={"section-#{section.id}"}
              rows={section.booking_groups}
              row_id={fn group -> "group-#{group.id}" end}
            >
              <:col :let={group} label="Time">{group.time}</:col>
              <:col :let={group} label="Holes">{BookingGroup.holes(group) || "—"}</:col>
              <:col :let={group} label="Entries">{length(group.booking_entries)}</:col>
              <:action :let={group}>
                <.link navigate={~p"/clubs/#{@club.id}/events/#{@event.id}/groups/#{group.id}"}>
                  View
                </.link>
              </:action>
            </.table>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
