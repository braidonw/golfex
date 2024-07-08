defmodule App.MiClub.BookingEvents do
  @moduledoc false

  alias App.MiClub
  alias App.MiClub.BookingEvent

  @spec sync_events(String.t()) :: {integer(), _} | {:error, term()}
  def sync_events(slug) do
    with {:ok, club} <- fetch_club_by_slug(slug), {:ok, events} <- MiClub.Server.list_events(club.slug) do
      events
      |> parse_events()
      |> Enum.filter(&is_valid_record?/1)
      |> Enum.map(&add_club_id(&1, club.id))
      |> insert_records()
    end
  end

  def fetch_club_by_slug(slug) do
    MiClub.Club
    |> App.Repo.get_by(slug: slug)
    |> case do
      nil -> {:error, :not_found}
      club -> {:ok, club}
    end
  end

  def insert_records(records) do
    timestamp = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    placeholders = %{timestamp: timestamp}

    records =
      Enum.map(records, fn record -> record |> Map.put(:inserted_at, timestamp) |> Map.put(:updated_at, timestamp) end)

    App.Repo.insert_all(BookingEvent, records,
      placeholders: placeholders,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:remote_id]
    )
  end

  def add_club_id(params, club_id), do: Map.put(params, :club_id, club_id)

  def parse_events(events_map) do
    Enum.map(events_map, &parse_booking_event/1)
  end

  def is_valid_record?(attrs), do: %BookingEvent{} |> BookingEvent.changeset(attrs) |> Map.get(:valid?)

  def parse_booking_event(event_map) do
    %{
      remote_id: to_string(event_map["bookingEventId"]),
      name: event_map["title"],
      date: parse_date(event_map["eventDate"]),
      # Not provided in the input map
      last_modified: nil,
      # Not provided in the input map
      last_modified_by_id: nil,
      status_code: to_string(event_map["eventStatusCode"]),
      status_code_friendly: event_map["eventStatusCodeFriendly"],
      booking_resource_id: event_map["bookingResourceId"],
      redirect_url: event_map["redirectUrl"],
      first_manual_upload_results: event_map["firstManualUploadResults"],
      is_lottery: event_map["isLottery"],
      can_open_event: event_map["canOpenEvent"],
      has_competition: event_map["hasCompetition"],
      matchplay_id: event_map["matchplayId"],
      event_type_code: event_map["eventTypeCode"],
      event_category_code: event_map["eventCategoryCode"],
      event_time_code_friendly: event_map["eventTimeCodeFriendly"],
      booking_note_action: event_map["bookingNoteAction"],
      auto_open_date_time_display: event_map["autoOpenDateTimeDisplay"],
      availability: event_map["availability"],
      is_ballot: event_map["isBallot"],
      is_ballot_open: event_map["isBallotOpen"],
      is_results: event_map["isResults"],
      is_open: event_map["isOpen"],
      is_female: event_map["isFemale"],
      is_male: event_map["isMale"],
      is_matchplay: event_map["isMatchplay"]
    }
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
