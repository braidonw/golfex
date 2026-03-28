defmodule GolfexWeb.BookingGroupLive.Show do
  use GolfexWeb, :live_view

  alias Golfex.Clubs
  alias Golfex.Events
  alias Golfex.Bookings
  alias Golfex.MiClub.BookingEvent
  alias Golfex.MiClub.BookingGroup

  @impl true
  def mount(
        %{"club_id" => club_id, "event_id" => event_id, "group_id" => group_id},
        _session,
        socket
      ) do
    group_id = String.to_integer(group_id)
    user_club = Clubs.get_user_club_by_club_id!(socket.assigns.current_scope, club_id)
    event = Events.get_event!(event_id)

    send(self(), :load_group_detail)

    {:ok,
     socket
     |> assign(:page_title, "Booking Group")
     |> assign(:user_club, user_club)
     |> assign(:club, user_club.club)
     |> assign(:event, event)
     |> assign(:group_id, group_id)
     |> assign(:group, nil)
     |> assign(:section, nil)
     |> assign(:loading, true)
     |> assign(:selected_row_id, nil)}
  end

  @impl true
  def handle_info(:load_group_detail, socket) do
    %{user_club: user_club, event: event, group_id: group_id} = socket.assigns

    socket =
      case Golfex.MiClub.get_event(user_club, event.miclub_event_id) do
        {:ok, booking_event} ->
          case BookingEvent.get_booking_group(booking_event, group_id) do
            {group, section} ->
              socket
              |> assign(:group, group)
              |> assign(:section, section)
              |> assign(:loading, false)

            nil ->
              socket
              |> assign(:loading, false)
              |> put_flash(:error, "Booking group not found.")
          end

        {:error, _reason} ->
          socket
          |> assign(:loading, false)
          |> put_flash(:error, "Failed to load event details.")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("book_now", %{"row_id" => row_id}, socket) do
    %{user_club: user_club, group_id: group_id, event: event} = socket.assigns
    row_id = String.to_integer(row_id)

    socket =
      case Bookings.book_now(user_club, group_id, row_id, user_club.member_id) do
        {:ok, _result} ->
          Events.invalidate_event(event)
          send(self(), :load_group_detail)

          socket
          |> assign(:loading, true)
          |> put_flash(:info, "Booking successful!")

        {:error, reason} ->
          put_flash(socket, :error, "Booking failed: #{inspect(reason)}")
      end

    {:noreply, socket}
  end

  def handle_event("select_row", %{"row_id" => row_id}, socket) do
    {:noreply, assign(socket, :selected_row_id, String.to_integer(row_id))}
  end

  def handle_event("schedule", %{"scheduled_for" => scheduled_for, "row_id" => row_id}, socket) do
    %{user_club: user_club, event: event, group_id: group_id, current_scope: scope} =
      socket.assigns

    row_id = String.to_integer(row_id)

    attrs = %{
      user_id: scope.user.id,
      user_club_id: user_club.id,
      event_id: event.id,
      miclub_event_id: event.miclub_event_id,
      miclub_group_id: group_id,
      miclub_row_id: row_id,
      miclub_member_id: user_club.member_id,
      scheduled_for: scheduled_for
    }

    socket =
      case Bookings.schedule_booking(attrs) do
        {:ok, _booking} ->
          socket
          |> put_flash(:info, "Booking scheduled successfully!")
          |> push_navigate(to: ~p"/bookings")

        {:error, reason} ->
          put_flash(socket, :error, "Failed to schedule booking: #{inspect(reason)}")
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flow">
      <.link navigate={~p"/clubs/#{@club.id}/events/#{@event.id}"}>
        ← Back to event
      </.link>

      <.header>
        {@event.title} — Group Detail
        <:subtitle>
          {Calendar.strftime(@event.event_date, "%d/%m/%Y")}
        </:subtitle>
      </.header>

      <%= if @loading do %>
        <p>Loading group details…</p>
      <% else %>
        <%= if @group do %>
          <dl class="grid grid-cols-[max-content_1fr] gap-x-4 gap-y-1">
            <dt class="font-semibold">Time</dt>
            <dd>{@group.time}</dd>

            <dt class="font-semibold">Holes</dt>
            <dd>{BookingGroup.holes(@group) || "—"}</dd>

            <dt class="font-semibold">Members accepted?</dt>
            <dd>{if @group.member_accepted, do: "Yes", else: "No"}</dd>

            <dt class="font-semibold">Visitors accepted?</dt>
            <dd>{if @group.visitor_accepted, do: "Yes", else: "No"}</dd>

            <dt class="font-semibold">Handicap Required?</dt>
            <dd>{if @group.require_handicap, do: "Yes", else: "No"}</dd>
          </dl>

          <h2 class="text-lg font-semibold mt-6">Entries</h2>

          <.table
            id="entries"
            rows={@group.booking_entries}
            row_id={fn entry -> "entry-#{entry.id}" end}
          >
            <:col :let={entry} label="#">{entry.index}</:col>
            <:col :let={entry} label="Name">{entry.person_name || "—"}</:col>
            <:col :let={entry} label="Handicap">{entry.handicap || "—"}</:col>
            <:col :let={entry} label="Membership">{entry.membership_number || "—"}</:col>
            <:action :let={entry}>
              <button
                phx-click="book_now"
                phx-value-row_id={entry.id}
                data-confirm="Book this slot now?"
              >
                Book
              </button>
            </:action>
            <:action :let={entry}>
              <button phx-click="select_row" phx-value-row_id={entry.id}>
                Schedule
              </button>
            </:action>
          </.table>

          <%= if @selected_row_id do %>
            <div class="mt-6 p-4 border rounded">
              <h3 class="text-base font-semibold mb-4">Schedule Booking</h3>
              <form phx-submit="schedule">
                <input type="hidden" name="row_id" value={@selected_row_id} />
                <div class="mb-4">
                  <label for="scheduled_for" class="block text-sm font-medium mb-1">
                    Scheduled for
                  </label>
                  <input
                    type="datetime-local"
                    id="scheduled_for"
                    name="scheduled_for"
                    required
                    class="rounded border-gray-300"
                  />
                </div>
                <.button type="submit">Schedule Booking</.button>
              </form>
            </div>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end
end
