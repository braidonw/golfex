defmodule GolfexWeb.BookingGroupLive.Show do
  use GolfexWeb, :live_view

  alias Golfex.Bookings
  alias Golfex.Clubs
  alias Golfex.Events
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
     |> assign(:loading, true)}
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
  def handle_event("book_now", _params, socket) do
    %{user_club: user_club, event: event, group_id: group_id} = socket.assigns

    socket =
      case Bookings.book_now(user_club, event.miclub_event_id, group_id) do
        :ok ->
          Events.invalidate_event(event)
          send(self(), :load_group_detail)

          socket
          |> assign(:loading, true)
          |> put_flash(:info, "Booking successful!")

        {:error, :no_empty_slots} ->
          put_flash(socket, :error, "No empty slots available in this group.")

        {:error, reason} ->
          put_flash(socket, :error, "Booking failed: #{inspect(reason)}")
      end

    {:noreply, socket}
  end

  def handle_event("schedule", %{"scheduled_for" => scheduled_for}, socket) do
    %{user_club: user_club, event: event, group_id: group_id, current_scope: scope} =
      socket.assigns

    attrs = %{
      user_id: scope.user.id,
      user_club_id: user_club.id,
      event_id: event.id,
      miclub_event_id: event.miclub_event_id,
      miclub_group_id: group_id,
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
          <strong>Date:</strong> {Calendar.strftime(@event.event_date, "%A %d %B %Y")}
        </:subtitle>
      </.header>

      <%= if @loading do %>
        <p>Loading group details…</p>
      <% else %>
        <%= if @group do %>
          <dl class="cluster dl-stacked">
            <div>
              <dt>Time</dt>
              <dd>{@group.time}</dd>
            </div>
            <div>
              <dt>Holes</dt>
              <dd>{BookingGroup.holes(@group) || "—"}</dd>
            </div>
            <div>
              <dt>Members accepted?</dt>
              <dd>{if @group.member_accepted, do: "Yes", else: "No"}</dd>
            </div>
            <div>
              <dt>Visitors accepted?</dt>
              <dd>{if @group.visitor_accepted, do: "Yes", else: "No"}</dd>
            </div>
            <div>
              <dt>Handicap Required?</dt>
              <dd>{if @group.require_handicap, do: "Yes", else: "No"}</dd>
            </div>
            <%= if @event.auto_open_date_time_display do %>
              <div>
                <dt>Opens for booking</dt>
                <dd>{@event.auto_open_date_time_display}</dd>
              </div>
            <% end %>
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
          </.table>

          <div class="mt-6">
            <%= if @event.is_open do %>
              <button
                phx-click="book_now"
                data-confirm="Book the first available slot now?"
                class="rounded-lg bg-zinc-900 px-3 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
              >
                Book Now
              </button>
            <% else %>
              <div class="p-4 border rounded">
                <h3 class="text-base font-semibold mb-4">Schedule Booking</h3>
                <form phx-submit="schedule">
                  <div class="mb-4">
                    <label for="scheduled_for" class="block text-sm font-medium mb-1">
                      Scheduled for
                    </label>
                    <input
                      type="datetime-local"
                      id="scheduled_for"
                      name="scheduled_for"
                      value={format_schedule_default(@event.auto_open_date_time_display)}
                      required
                      class="rounded border-gray-300"
                    />
                  </div>
                  <.button type="submit">Schedule Booking</.button>
                </form>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Attempt to convert autoOpenDateTimeDisplay (e.g. "15/01/2024 7:00 AM")
  # into datetime-local format ("2024-01-15T07:00") for the input default value.
  # Returns nil if parsing fails — the input will just be empty.
  defp format_schedule_default(nil), do: nil

  defp format_schedule_default(display_string) do
    # MiClub format: "DD/MM/YYYY h:mm AM/PM"
    case Regex.run(
           ~r/(\d{1,2})\/(\d{1,2})\/(\d{4})\s+(\d{1,2}):(\d{2})\s*(AM|PM)/i,
           display_string
         ) do
      [_, day, month, year, hour, minute, ampm] ->
        hour = String.to_integer(hour)
        hour = if String.upcase(ampm) == "PM" and hour != 12, do: hour + 12, else: hour
        hour = if String.upcase(ampm) == "AM" and hour == 12, do: 0, else: hour

        "#{year}-#{String.pad_leading(month, 2, "0")}-#{String.pad_leading(day, 2, "0")}T#{String.pad_leading(Integer.to_string(hour), 2, "0")}:#{minute}"

      _ ->
        nil
    end
  end
end
