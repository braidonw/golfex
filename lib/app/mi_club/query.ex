defmodule App.MiClub.Query do
  @moduledoc false
  import Ecto.Query

  alias App.MiClub.BookingEvent

  def event_base do
    from e in BookingEvent, as: :booking_event, join: c in assoc(e, :club), as: :club
  end

  def by_club(query, club_slug) do
    where(query, [club: club], club.slug == ^club_slug)
  end

  def order_by_date(query) do
    order_by(query, [booking_event: booking_event], asc: booking_event.date)
  end
end
