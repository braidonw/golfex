defmodule App.MiClub.Api do
  @moduledoc false

  def list_events(req) do
    case Req.get(req, url: "/spring/bookings/events/between/#{current_date()}/#{to_date()}/3000000") do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 401}} -> {:error, :auth_error}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_event(req, event_id) do
    Req.get(req, url: "/spring/bookings/events/#{event_id}")
  end

  def login(req, username, password) do
    Req.post(req,
      url: "/security/login.msp",
      form: %{user: username, password: password, action: "login", submit: "Login"}
    )
  end

  defp current_date, do: DateTime.utc_now() |> DateTime.to_date() |> format_date()
  defp to_date, do: DateTime.utc_now() |> DateTime.add(1000, :day) |> DateTime.to_date() |> format_date()
  defp format_date(date), do: "#{date.day}-#{date.month}-#{date.year}"
end
