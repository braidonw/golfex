defmodule Golfex.Events do
  import Ecto.Query

  alias Golfex.Repo
  alias Golfex.Events.Event
  alias Golfex.Clubs.Club

  @cache_max_age_hours 12

  def list_events_for_club(%Club{} = club) do
    Event
    |> where(club_id: ^club.id)
    |> order_by(asc: :event_date)
    |> Repo.all()
  end

  def get_event!(id) do
    Repo.get!(Event, id)
  end

  def cache_stale?(%Club{} = club) do
    cutoff = DateTime.add(DateTime.utc_now(), -@cache_max_age_hours, :hour)

    query =
      Event
      |> where(club_id: ^club.id)
      |> where([e], e.cached_at > ^cutoff)

    Repo.aggregate(query, :count) == 0
  end

  def upsert_events(%Club{} = club, miclub_events) when is_list(miclub_events) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(miclub_events, fn e ->
        %{
          id: Ecto.UUID.generate(),
          club_id: club.id,
          miclub_event_id: e.id,
          title: e.title,
          event_date: e.event_date,
          event_status_code: e[:event_status_code],
          event_status_code_friendly: e[:event_status_code_friendly],
          availability: e[:availability] || 0,
          is_open: e[:is_open] || false,
          is_ballot: e[:is_ballot] || false,
          is_ballot_open: e[:is_ballot_open] || false,
          is_lottery: e[:is_lottery],
          has_competition: e[:has_competition],
          is_matchplay: e[:is_matchplay] || false,
          is_results: e[:is_results] || false,
          event_type_code: e[:event_type_code],
          event_category_code: e[:event_category_code],
          event_time_code_friendly: e[:event_time_code_friendly],
          auto_open_date_time_display: e[:auto_open_date_time_display],
          cached_at: now,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(Event, entries,
      on_conflict: {:replace_all_except, [:id, :club_id, :inserted_at]},
      conflict_target: [:club_id, :miclub_event_id]
    )
  end

  def invalidate_event(%Event{} = event) do
    stale_time = DateTime.add(DateTime.utc_now(), -(@cache_max_age_hours + 1), :hour)

    event
    |> Ecto.Changeset.change(cached_at: DateTime.truncate(stale_time, :second))
    |> Repo.update()
  end

  def invalidate_events(%Club{} = club) do
    stale_time =
      DateTime.utc_now()
      |> DateTime.add(-(@cache_max_age_hours + 1), :hour)
      |> DateTime.truncate(:second)

    Event
    |> where(club_id: ^club.id)
    |> Repo.update_all(set: [cached_at: stale_time])
  end
end
