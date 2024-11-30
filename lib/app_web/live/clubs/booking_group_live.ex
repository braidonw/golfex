defmodule AppWeb.Clubs.BookingGroupLive do
  @moduledoc false
  use AppWeb, :live_view

  def mount(params, _session, socket) do
    params = Map.take(params, ["slug", "event_id", "booking_group_id"])
    %{"slug" => slug, "event_id" => event_id, "booking_group_id" => booking_group_id} = params

    {:ok, club} = App.MiClub.fetch_club_by_slug(slug)
    {:ok, event} = App.MiClub.fetch_event(event_id)
    event = App.Repo.preload(event, booking_groups: :booking_entries)
    booking_group = Enum.find(event.booking_groups, fn bg -> bg.id == String.to_integer(booking_group_id) end)

    socket = assign(socket, club: club, event: event, booking_group: booking_group)
    {:ok, socket}
  end
end
