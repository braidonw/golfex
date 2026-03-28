defmodule Golfex.MiClub.BookingGroupTest do
  use ExUnit.Case, async: true

  alias Golfex.MiClub.{BookingEntry, BookingGroup}

  describe "first_empty_entry/1" do
    test "returns first entry with no person_name" do
      group = %BookingGroup{
        id: 1,
        booking_entries: [
          %BookingEntry{id: 100, index: 1, person_name: "John Smith"},
          %BookingEntry{id: 101, index: 2, person_name: nil},
          %BookingEntry{id: 102, index: 3, person_name: nil}
        ]
      }

      assert {:ok, %BookingEntry{id: 101}} = BookingGroup.first_empty_entry(group)
    end

    test "treats empty string person_name as empty" do
      group = %BookingGroup{
        id: 1,
        booking_entries: [
          %BookingEntry{id: 100, index: 1, person_name: ""}
        ]
      }

      assert {:ok, %BookingEntry{id: 100}} = BookingGroup.first_empty_entry(group)
    end

    test "returns :none when all slots are taken" do
      group = %BookingGroup{
        id: 1,
        booking_entries: [
          %BookingEntry{id: 100, index: 1, person_name: "John Smith"},
          %BookingEntry{id: 101, index: 2, person_name: "Jane Doe"}
        ]
      }

      assert :none = BookingGroup.first_empty_entry(group)
    end

    test "returns :none when there are no entries" do
      group = %BookingGroup{id: 1, booking_entries: []}
      assert :none = BookingGroup.first_empty_entry(group)
    end
  end
end
