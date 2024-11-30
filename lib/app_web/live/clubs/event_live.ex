defmodule AppWeb.Clubs.EventLive do
  @moduledoc false
  use AppWeb, :live_view

  alias App.MiClub.Booking
  alias App.MiClub.BookingGroup

  def mount(%{"slug" => slug, "event_id" => id}, _session, socket) do
    {:ok, club} = App.MiClub.fetch_club_by_slug(slug)
    {:ok, event} = App.MiClub.fetch_event(id)
    App.MiClub.refresh_event(slug, event.remote_id)
    event = App.Repo.preload(event, booking_groups: :booking_entries)

    {:ok,
     socket
     |> assign(event: event, club: club)
     |> assign_async(:booking_sections, fn -> fetch_booking_sections(event) end)}
  end

  def handle_event("book", %{"group_id" => booking_group_id}, socket) do
    %{assigns: %{club: %{slug: slug}}} = socket
    Booking.book_event(slug, booking_group_id)
    {:noreply, socket}
  end

  defp fetch_booking_sections(event) do
    _remote_id = event.remote_id
    {:ok, %{booking_sections: []}}
  end
end
