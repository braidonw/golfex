defmodule Golfex.MiClub.Client do
  @login_path "security/login.msp"
  @events_path "spring/bookings/events/between"
  @event_path "spring/bookings/events"
  @ajax_path "members/Ajax"

  def login(base_url, username, password) do
    req = build_req(base_url)

    form_data = [
      user: username,
      password: password,
      action: "login",
      Submit: "Login"
    ]

    case Req.post(req, url: @login_path, form: form_data) do
      {:ok, %Req.Response{status: status}} when status in 200..399 ->
        {:ok, req}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:login_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_events(req) do
    date_from = Calendar.strftime(Date.utc_today(), "%d-%m-%Y")
    date_to = Calendar.strftime(Date.add(Date.utc_today(), 60), "%d-%m-%Y")
    url = "#{@events_path}/#{date_from}/#{date_to}/3000000"

    case Req.get(req, url: url) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, Jason.encode!(body)}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_event(req, event_id) do
    case Req.get(req, url: "#{@event_path}/#{event_id}") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def book(req, booking_group_id, row_id, member_id) do
    form_data = [
      doAction: "makeBooking",
      rowId: to_string(row_id),
      memberId: to_string(member_id),
      myGroup: to_string(booking_group_id),
      findAlternative: "false"
    ]

    case Req.post(req, url: @ajax_path, form: form_data) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_req(base_url) do
    opts = [
      base_url: base_url,
      redirect: false,
      receive_timeout: 30_000
    ]

    # In test, use the Req.Test plug; in prod/dev, make real HTTP requests
    test_opts = Application.get_env(:golfex, :miclub_req_options, [])
    Req.new(Keyword.merge(opts, test_opts))
  end
end
