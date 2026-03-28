defmodule Golfex.MiClub do
  alias Golfex.MiClub.{Client, Parser, SessionStore}

  def login(user_club) do
    Client.login(user_club.club.base_url, user_club.username, user_club.password)
  end

  def list_events(user_club) do
    with_session(user_club, fn req, jar ->
      with {:ok, body} <- Client.get_events(req, jar),
           {:ok, events} <- Parser.parse_events(body) do
        {:ok, events}
      end
    end)
  end

  def get_event(user_club, event_id) do
    with_session(user_club, fn req, jar ->
      with {:ok, body} <- Client.get_event(req, jar, event_id) |> dbg(),
           {:ok, event} <- Parser.parse_event_detail(body) |> dbg() do
        {:ok, event}
      end
    end)
  end

  def book(user_club, booking_group_id, row_id, member_id) do
    with_session(user_club, fn req, jar ->
      with {:ok, body} <- Client.book(req, jar, booking_group_id, row_id, member_id) do
        Parser.parse_booking_response(body)
      end
    end)
  end

  # Executes `fun` with a cached session. On 401, invalidates the session
  # and retries once with a fresh login.
  defp with_session(user_club, fun) do
    case get_session(user_club) do
      {:ok, req, jar} ->
        case fun.(req, jar) do
          {:error, {:http_error, 401}} ->
            SessionStore.invalidate(user_club.user_id, user_club.club_id)
            retry_with_fresh_session(user_club, fun)

          result ->
            result
        end

      {:error, _} = error ->
        error
    end
  end

  defp retry_with_fresh_session(user_club, fun) do
    case get_session(user_club) do
      {:ok, req, jar} -> fun.(req, jar)
      {:error, _} = error -> error
    end
  end

  # In test, bypass the SessionStore (Req.Test expectations are process-owned).
  # In dev/prod, use the session cache.
  defp get_session(user_club) do
    if Application.get_env(:golfex, :miclub_session_store, true) do
      SessionStore.get_or_login(user_club)
    else
      Client.login(user_club.club.base_url, user_club.username, user_club.password)
    end
  end
end
