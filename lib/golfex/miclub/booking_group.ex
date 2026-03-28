defmodule Golfex.MiClub.BookingGroup do
  defstruct [
    :id,
    :time,
    :status_code,
    :active,
    :require_handicap,
    :require_golf_link,
    :visitor_accepted,
    :member_accepted,
    :public_member_accepted,
    :nine_holes,
    :eighteen_holes,
    booking_entries: []
  ]

  def holes(%__MODULE__{nine_holes: true}), do: 9
  def holes(%__MODULE__{eighteen_holes: true}), do: 18
  def holes(_), do: nil

  def first_empty_entry(%__MODULE__{booking_entries: entries}) do
    case Enum.find(entries, fn entry ->
      is_nil(entry.person_name) or entry.person_name == ""
    end) do
      nil -> :none
      entry -> {:ok, entry}
    end
  end
end
