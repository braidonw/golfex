defmodule Golfex.MiClub.Client do
  @login_path "security/login.msp"
  @events_path "spring/bookings/events/between"
  @event_path "spring/bookings/events"
  @ajax_path "members/Ajax"

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36"

  def login(base_url, username, password) do
    jar = HttpCookie.Jar.new()
    req = build_req(base_url)

    # Step 1: GET the login page to establish a session and find hidden form fields
    case Req.get(req, url: @login_path, cookie_jar: jar) do
      {:ok, %Req.Response{status: 200, body: body} = resp} ->
        jar = resp.private[:cookie_jar] || jar
        hidden_fields = extract_hidden_fields(body)

        # Step 2: POST login with credentials + any hidden fields
        # Our explicit values override hidden fields with the same name
        explicit_fields = %{
          "user" => username,
          "password" => password,
          "action" => "login",
          "Submit" => "Login"
        }

        form_data =
          hidden_fields
          |> Map.new()
          |> Map.merge(explicit_fields)
          |> Enum.to_list()

        case Req.post(req, url: @login_path, form: form_data, cookie_jar: jar) do
          {:ok, %Req.Response{status: status} = resp} when status in 200..399 ->
            jar = resp.private[:cookie_jar] || jar
            # Check if login succeeded - a successful login typically redirects,
            # or the response body won't contain the login form
            body_str = if is_binary(resp.body), do: resp.body, else: ""
            login_succeeded = not String.contains?(body_str, "<title>Highend : Login</title>")

            if login_succeeded do
              {:ok, req, jar}
            else
              {:error, :login_failed}
            end

          {:ok, %Req.Response{status: status}} ->
            {:error, {:login_failed, status}}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, {:login_page_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_events(req, jar) do
    date_from = Calendar.strftime(Date.utc_today(), "%d-%m-%Y")
    date_to = Calendar.strftime(Date.add(Date.utc_today(), 60), "%d-%m-%Y")
    url = "#{@events_path}/#{date_from}/#{date_to}/3000000"

    case Req.get(req, url: url, cookie_jar: jar) do
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

  def get_event(req, jar, event_id) do
    case Req.get(req, url: "#{@event_path}/#{event_id}", cookie_jar: jar) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def book(req, jar, booking_group_id, row_id, member_id) do
    form_data = [
      doAction: "makeBooking",
      rowId: to_string(row_id),
      memberId: to_string(member_id),
      myGroup: to_string(booking_group_id),
      findAlternative: "false"
    ]

    case Req.post(req, url: @ajax_path, form: form_data, cookie_jar: jar) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Build a Req struct for the given base URL with HttpCookie plugin attached.
  """
  def build_req(base_url) do
    opts = [
      base_url: base_url,
      receive_timeout: 30_000,
      headers: [
        user_agent: @user_agent
      ]
    ]

    test_opts = Application.get_env(:golfex, :miclub_req_options, [])

    Req.new(Keyword.merge(opts, test_opts))
    |> HttpCookie.ReqPlugin.attach()
  end

  # Parse hidden input fields from an HTML form body.
  # Returns a list of {"name", "value"} tuples.
  defp extract_hidden_fields(body) when is_binary(body) do
    ~r/<input[^>]+type=["']hidden["'][^>]*>/i
    |> Regex.scan(body)
    |> Enum.flat_map(fn [tag] ->
      name = Regex.run(~r/name=["']([^"']*)["']/i, tag)
      value = Regex.run(~r/value=["']([^"']*)["']/i, tag)

      case {name, value} do
        {[_, n], [_, v]} -> [{n, v}]
        {[_, n], nil} -> [{n, ""}]
        _ -> []
      end
    end)
  end

  defp extract_hidden_fields(_), do: []
end
