defmodule Golfex.MiClub.Parser do
  import SweetXml

  alias Golfex.MiClub.{BookingEvent, BookingSection, BookingGroup, BookingEntry}

  def parse_events(json) do
    case Jason.decode(json) do
      {:ok, events} when is_list(events) ->
        parsed =
          Enum.map(events, fn e ->
            %{
              id: e["Id"],
              title: e["Title"],
              event_date: parse_date(e["EventDate"]),
              availability: e["Availability"],
              is_open: e["IsOpen"],
              is_ballot: e["IsBallot"],
              is_ballot_open: e["IsBallotOpen"],
              is_lottery: e["IsLottery"],
              has_competition: e["HasCompetition"],
              is_matchplay: e["IsMatchplay"],
              is_results: e["IsResults"],
              event_status_code: e["EventStatusCode"],
              event_status_code_friendly: e["EventStatusCodeFriendly"],
              event_type_code: e["EventTypeCode"],
              event_category_code: e["EventCategoryCode"],
              event_time_code_friendly: e["EventTimeCodeFriendly"],
              auto_open_date_time_display: e["AutoOpenDateTimeDisplay"]
            }
          end)

        {:ok, parsed}

      {:ok, _} ->
        {:error, :unexpected_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_event_detail(xml) do
    try do
      doc = SweetXml.parse(xml)

      event = %BookingEvent{
        id: doc |> xpath(~x"//BookingEvent/Id/text()"s) |> to_integer(),
        active: doc |> xpath(~x"//BookingEvent/Active/text()"s) |> to_boolean(),
        name: doc |> xpath(~x"//BookingEvent/Name/text()"s),
        date: doc |> xpath(~x"//BookingEvent/Date/text()"s),
        last_modified: doc |> xpath(~x"//BookingEvent/LastModified/text()"s),
        booking_sections: parse_sections(doc)
      }

      {:ok, event}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  def parse_booking_response(xml) do
    if String.contains?(xml, "<Error>") do
      try do
        doc = SweetXml.parse(xml)
        error_texts = doc |> xpath(~x"//Error/ErrorText/text()"ls)
        {:error, Enum.join(error_texts, ", ")}
      rescue
        _ -> {:error, "Unknown booking error"}
      end
    else
      :ok
    end
  end

  defp parse_sections(doc) do
    doc
    |> xpath(~x"//BookingSections/BookingSection"l)
    |> Enum.map(fn section ->
      %BookingSection{
        id: section |> xpath(~x"./Id/text()"s) |> to_integer(),
        active: section |> xpath(~x"./Active/text()"s) |> to_boolean(),
        name: section |> xpath(~x"./Name/text()"s),
        booking_groups: parse_groups(section)
      }
    end)
  end

  defp parse_groups(section) do
    section
    |> xpath(~x"./BookingGroups/BookingGroup"l)
    |> Enum.map(fn group ->
      %BookingGroup{
        id: group |> xpath(~x"./Id/text()"s) |> to_integer(),
        time: group |> xpath(~x"./Time/text()"s),
        status_code: group |> xpath(~x"./StatusCode/text()"s) |> to_integer(),
        active: group |> xpath(~x"./Active/text()"s) |> to_boolean(),
        require_handicap: group |> xpath(~x"./RequireHandicap/text()"s) |> to_boolean(),
        require_golf_link: group |> xpath(~x"./RequireGolfLink/text()"s) |> to_boolean(),
        visitor_accepted: group |> xpath(~x"./VisitorAccepted/text()"s) |> to_boolean(),
        member_accepted: group |> xpath(~x"./MemberAccepted/text()"s) |> to_boolean(),
        public_member_accepted: group |> xpath(~x"./PublicMemberAccepted/text()"s) |> to_boolean(),
        nine_holes: group |> xpath(~x"./NineHoles/text()"s) |> to_boolean(),
        eighteen_holes: group |> xpath(~x"./EighteenHoles/text()"s) |> to_boolean(),
        booking_entries: parse_entries(group)
      }
    end)
  end

  defp parse_entries(group) do
    group
    |> xpath(~x"./BookingEntries/BookingEntry"l)
    |> Enum.map(fn entry ->
      %BookingEntry{
        id: entry |> xpath(~x"./Id/text()"s) |> to_integer(),
        kind: entry |> xpath(~x"./Type/text()"s),
        index: entry |> xpath(~x"./Index/text()"s) |> to_integer(),
        person_name: entry |> xpath(~x"./PersonName/text()"s),
        membership_number: entry |> xpath(~x"./MembershipNumber/text()"s) |> nilify(),
        gender: entry |> xpath(~x"./Gender/text()"s) |> nilify(),
        handicap: entry |> xpath(~x"./Handicap/text()"s) |> to_float_or_nil(),
        golf_link_no: entry |> xpath(~x"./GolfLinkNo/text()"s) |> nilify()
      }
    end)
  end

  defp to_integer(s), do: String.to_integer(s)
  defp to_boolean("true"), do: true
  defp to_boolean(_), do: false
  defp nilify(""), do: nil
  defp nilify(s), do: s

  defp to_float_or_nil(""), do: nil

  defp to_float_or_nil(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_string) do
    case NaiveDateTime.from_iso8601(date_string) do
      {:ok, ndt} -> NaiveDateTime.to_date(ndt)
      _ -> nil
    end
  end
end
