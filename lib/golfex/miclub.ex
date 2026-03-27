defmodule Golfex.MiClub do
  alias Golfex.MiClub.{Client, Parser}

  def login(user_club) do
    Client.login(user_club.club.base_url, user_club.username, user_club.password)
  end

  def list_events(user_club) do
    with {:ok, req} <- Client.login(user_club.club.base_url, user_club.username, user_club.password),
         {:ok, body} <- Client.get_events(req),
         {:ok, events} <- Parser.parse_events(body) do
      {:ok, events}
    end
  end

  def get_event(user_club, event_id) do
    with {:ok, req} <- Client.login(user_club.club.base_url, user_club.username, user_club.password),
         {:ok, body} <- Client.get_event(req, event_id),
         {:ok, event} <- Parser.parse_event_detail(body) do
      {:ok, event}
    end
  end

  def book(user_club, booking_group_id, row_id, member_id) do
    with {:ok, req} <- Client.login(user_club.club.base_url, user_club.username, user_club.password),
         {:ok, body} <- Client.book(req, booking_group_id, row_id, member_id) do
      Parser.parse_booking_response(body)
    end
  end
end
