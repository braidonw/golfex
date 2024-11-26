defmodule App.MiClub do
  @moduledoc false

  alias App.MiClub.Api
  alias App.MiClub.Auth
  alias App.MiClub.BookingEntry
  alias App.MiClub.BookingEvent
  alias App.MiClub.BookingGroup
  alias App.MiClub.BookingSection
  alias App.MiClub.Club
  alias App.MiClub.Query
  alias App.Repo

  def list_clubs do
    Repo.all(Club)
  end

  def refresh_event(slug, event_id) do
    with {:ok, club} <- fetch_club_by_slug(slug),
         {:ok, existing_event} <- App.Repo.fetch_by(BookingEvent, remote_id: event_id),
         {:ok, token} <- Auth.get_or_fetch_cookie(club.id),
         {:ok, event} <- Api.get_event(slug, token, event_id) do
      File.write("text.txt", event)
      parsed = App.MiClub.Api.XmlParser.parse_event(event)

      # Create Ecto changesets and insert into database
      event_changeset = BookingEvent.changeset(existing_event, parsed)

      {:ok, event} =
        Repo.insert(event_changeset,
          on_conflict: {:replace_all_except, [:id, :inserted_at]},
          conflict_target: [:club_id, :remote_id]
        )

      # Insert sections
      Enum.each(parsed.booking_sections, fn section ->
        section_params = Map.put(section, :booking_event_id, event.id)
        section_changeset = BookingSection.changeset(%BookingSection{}, section_params)

        {:ok, db_section} =
          Repo.insert(section_changeset,
            on_conflict: {:replace_all_except, [:id, :remote_id, :inserted_at]},
            conflict_target: [:remote_id]
          )

        # Insert groups
        Enum.each(section.booking_groups, fn group ->
          group_params = Map.put(group, :booking_section_id, db_section.id)
          group_changeset = BookingGroup.changeset(%BookingGroup{}, group_params)

          {:ok, db_group} =
            Repo.insert(group_changeset,
              on_conflict: {:replace_all_except, [:id, :remote_id, :inserted_at]},
              conflict_target: :remote_id
            )

          # Insert entries if any
          Enum.each(group.booking_entries, fn entry ->
            entry_params = Map.put(entry, :booking_group_id, db_group.id)
            entry_changeset = BookingEntry.changeset(%BookingEntry{}, entry_params)

            Repo.insert(entry_changeset,
              on_conflict: {:replace_all_except, [:id, :remote_id, :inserted_at]},
              conflict_target: :remote_id
            )
          end)
        end)
      end)

      IO.puts("Event: #{inspect(event)}")
    end
  end

  def refresh_events(slug) do
    with {:ok, club} <- fetch_club_by_slug(slug),
         {:ok, token} <- Auth.get_or_fetch_cookie(club.id),
         {:ok, events} <- Api.list_events(slug, token) do
      for event <- events, reduce: {:ok, []} do
        {:ok, current} ->
          params = map_booking_event_response_to_schema(event)

          case %BookingEvent{club_id: club.id}
               |> BookingEvent.changeset(params)
               |> Repo.insert(on_conflict: :replace_all, conflict_target: [:club_id, :remote_id]) do
            {:ok, record} -> {:ok, [record | current]}
            {:error, changeset} -> {:error, changeset}
          end

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  defp map_booking_event_response_to_schema(response) do
    %{
      remote_id: to_string(response["bookingEventId"]),
      name: response["title"],
      date: Date.from_iso8601!(response["eventDate"]),
      # Note: last_modified and last_modified_by_id aren't in the response
      last_modified: nil,
      last_modified_by_id: nil,
      status_code: to_string(response["eventStatusCode"]),
      status_code_friendly: response["eventStatusCodeFriendly"],
      booking_resource_id: response["bookingResourceId"],
      redirect_url: response["redirectUrl"],
      first_manual_upload_results: response["firstManualUploadResults"],
      is_lottery: response["isLottery"],
      can_open_event: response["canOpenEvent"],
      has_competition: response["hasCompetition"],
      matchplay_id: response["matchplayId"],
      event_type_code: response["eventTypeCode"],
      event_category_code: response["eventCategoryCode"],
      event_time_code_friendly: response["eventTimeCodeFriendly"],
      booking_note_action: response["bookingNoteAction"],
      auto_open_date_time_display: response["autoOpenDateTimeDisplay"],
      availability: response["availability"],
      is_ballot: response["isBallot"],
      is_ballot_open: response["isBallotOpen"],
      is_results: response["isResults"],
      is_open: response["isOpen"],
      is_female: response["isFemale"],
      is_male: response["isMale"],
      is_matchplay: response["isMatchplay"]
    }
  end

  def get_club!(slug) do
    Repo.get_by(Club, slug: slug) || raise "Club not found"
  end

  def fetch_club_by_slug(slug) do
    Repo.fetch_by(Club, slug: slug)
  end

  def fetch_club_by_id(id) do
    Repo.fetch(Club, id)
  end

  def fetch_event(event_id), do: Repo.fetch(BookingEvent, event_id)

  def list_club_events(slug) do
    Query.event_base() |> Query.by_club(slug) |> Query.order_by_date() |> Repo.all()
  end
end
