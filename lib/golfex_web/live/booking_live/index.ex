defmodule GolfexWeb.BookingLive.Index do
  use GolfexWeb, :live_view

  alias Golfex.Bookings

  @impl true
  def mount(_params, _session, socket) do
    bookings = Bookings.list_bookings_for_user(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "My Bookings")
     |> assign(:bookings, bookings)}
  end

  @impl true
  def handle_event("cancel", %{"id" => id}, socket) do
    booking = Bookings.get_scheduled_booking!(id)

    case Bookings.cancel_booking(booking) do
      {:ok, _booking} ->
        bookings = Bookings.list_bookings_for_user(socket.assigns.current_scope)
        {:noreply, assign(socket, :bookings, bookings)}

      {:error, :not_cancellable} ->
        {:noreply, put_flash(socket, :error, "This booking can no longer be cancelled.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flow">
      <.header>
        My Bookings
      </.header>

      <%= if @bookings == [] do %>
        <p>No scheduled bookings.</p>
      <% else %>
        <.table id="bookings" rows={@bookings} row_id={fn b -> "booking-#{b.id}" end}>
          <:col :let={b} label="Event ID">{b.miclub_event_id}</:col>
          <:col :let={b} label="Scheduled For">
            {Calendar.strftime(b.scheduled_for, "%d/%m/%Y %H:%M")}
          </:col>
          <:col :let={b} label="Status">{b.status}</:col>
          <:col :let={b} label="Error">{b.last_error || "-"}</:col>
          <:action :let={b}>
            <%= if b.status == "pending" do %>
              <.link
                phx-click="cancel"
                phx-value-id={b.id}
                data-confirm="Are you sure you want to cancel this booking?"
              >
                Cancel
              </.link>
            <% end %>
          </:action>
        </.table>
      <% end %>
    </div>
    """
  end
end
