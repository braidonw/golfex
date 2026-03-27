defmodule Golfex.MiClub.BookingEvent do
  defstruct [
    :id,
    :active,
    :date,
    :name,
    :last_modified,
    booking_sections: []
  ]

  def get_booking_group(%__MODULE__{booking_sections: sections}, group_id) do
    Enum.find_value(sections, fn section ->
      case Enum.find(section.booking_groups, &(&1.id == group_id)) do
        nil -> nil
        group -> {group, section}
      end
    end)
  end
end
