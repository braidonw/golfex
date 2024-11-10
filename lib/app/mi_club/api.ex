defmodule App.MiClub.Api do
  @moduledoc false
  alias App.MiClub.Auth

  require Logger

  def get_event(slug, token, event_id) do
    opts = config(slug)

    [base_url: Keyword.get(opts, :base_url)]
    |> Req.new()
    |> Req.Request.put_header("cookie", token)
    |> Req.get(url: "/spring/bookings/events/#{event_id}")
    |> case do
      {:ok, %{status: 401}} ->
        {:ok, cookie} = Auth.get_cookie_by_token(token)
        Auth.invalidate_cookie(cookie)

      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
    end
  end

  def list_events(slug, token) do
    opts = config(slug)

    cookie = "JSESSIONID=#{token}"
    # cookie = "JSESSIONID=B7C7B6C3EF8842024D91F5C03EDB6C9B"

    [base_url: Keyword.get(opts, :base_url)]
    |> Req.new()
    |> Req.Request.put_header("cookie", cookie)
    |> CurlReq.Plugin.attach()
    |> Req.get(url: "/spring/bookings/events/between/10-11-2024/14-1-2025/3000000")
    |> dbg()
    |> case do
      {:ok, %{status: 401}} ->
        {:ok, cookie} = Auth.get_cookie_by_token(token)
        {:ok, updated_cookie} = Auth.invalidate_cookie(cookie)
        {:error, :unauthorized}

      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
    end
  end

  @spec login(atom()) :: {:ok, String.t()} | {:error, term()}
  def login(slug) do
    opts = config(slug)
    user = Keyword.get(opts, :username)
    password = Keyword.get(opts, :password)

    dbg(user)
    dbg(password)

    response =
      [base_url: Keyword.get(opts, :base_url)]
      |> Req.new()
      |> CurlReq.Plugin.attach()
      |> Req.post(
        url: "/security/login.msp",
        form: dbg(%{user: user, password: password, action: "login", submit: "Login"})
      )

    case response do
      {:ok, %{status: 200} = resp} ->
        set_cookies = Req.Response.get_header(resp, "set-cookie")

        auth_cookie =
          set_cookies |> Enum.find(&String.contains?(&1, "JSESSIONID")) |> String.split(";") |> List.first()

        if is_nil(auth_cookie) do
          raise "Failed to parse token from headers: #{inspect(set_cookies)}"
        end

        [_, auth_cookie] = String.split(auth_cookie, "=")

        {:ok, auth_cookie}

      {:ok, resp} ->
        Logger.error("Failed to login to #{slug} - #{inspect(resp)}")

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp config(slug) do
    slug = String.to_existing_atom(slug)
    config = :app |> Application.get_env(:miclub) |> Keyword.get(slug)

    [username: config[:username], password: config[:password], base_url: config[:base_url]]
  end

  defp current_date, do: DateTime.utc_now() |> DateTime.to_date() |> format_date()
  defp to_date, do: DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.to_date() |> format_date()
  defp format_date(date), do: "#{date.day}-#{date.month}-#{date.year}"

  defmodule XmlParser do
    @moduledoc false
    alias __MODULE__.EventHandler

    def parse_event(xml) do
      {:ok, parsed} = Saxy.parse_string(xml, EventHandler, initial_state: %{})
      parsed
    end

    defmodule EventHandler do
      @moduledoc false
      @behaviour Saxy.Handler

      def handle_event(:start_document, _prolog, state) do
        {:ok, state}
      end

      def handle_event(:end_document, _data, state) do
        {:ok, state}
      end

      def handle_event(:start_element, {"BookingEvent", attributes}, _state) do
        event = %{
          remote_id: find_attribute(attributes, "id"),
          booking_sections: [],
          name: nil,
          date: nil,
          active: nil,
          last_modified: nil,
          last_modified_by_id: nil
        }

        {:ok, event}
      end

      def handle_event(:start_element, {"Name", _}, state) do
        {:ok, Map.put(state, :current_element, :name)}
      end

      def handle_event(:start_element, {"Date", _}, state) do
        {:ok, Map.put(state, :current_element, :date)}
      end

      def handle_event(:start_element, {"active", _}, state) do
        {:ok, Map.put(state, :current_element, :active)}
      end

      def handle_event(:start_element, {"lastModified", _}, state) do
        {:ok, Map.put(state, :current_element, :last_modified)}
      end

      def handle_event(:start_element, {"lastModifierId", _}, state) do
        {:ok, Map.put(state, :current_element, :last_modified_by_id)}
      end

      def handle_event(:start_element, {"BookingSection", attributes}, state) do
        section = %{
          remote_id: find_attribute(attributes, "id"),
          active: nil,
          name: nil,
          booking_groups: []
        }

        sections = state.booking_sections || []

        {:ok,
         state
         |> Map.put(:current_section, section)
         |> Map.put(:booking_sections, sections)}
      end

      def handle_event(:start_element, {"BookingGroup", attributes}, state) do
        group = %{
          remote_id: find_attribute(attributes, "id"),
          active: nil,
          name: nil,
          time: nil,
          status_code: nil,
          require_gender: false,
          require_golf_link: false,
          require_handicap: false,
          require_home_club: false,
          visitor_accepted: false,
          member_accepted: false,
          public_member_accepted: false,
          nine_holes: false,
          eighteen_holes: false,
          booking_entries: []
        }

        {:ok, Map.put(state, :current_group, group)}
      end

      def handle_event(:characters, text, %{current_element: :name} = state) do
        {:ok, state |> Map.put(:name, text) |> Map.delete(:current_element)}
      end

      def handle_event(:characters, text, %{current_element: :date} = state) do
        {:ok, state |> Map.put(:date, parse_date(text)) |> Map.delete(:current_element)}
      end

      def handle_event(:characters, text, %{current_element: :active} = state) do
        {:ok, state |> Map.put(:active, text == "true") |> Map.delete(:current_element)}
      end

      def handle_event(:characters, text, %{current_element: :last_modified} = state) do
        {:ok, state |> Map.put(:last_modified, parse_datetime(text)) |> Map.delete(:current_element)}
      end

      def handle_event(:characters, text, %{current_element: :last_modified_by_id} = state) do
        {:ok, state |> Map.put(:last_modified_by_id, text) |> Map.delete(:current_element)}
      end

      def handle_event(:end_element, "BookingSection", state) do
        section = state.current_section
        sections = [section | state.booking_sections]
        {:ok, state |> Map.put(:booking_sections, sections) |> Map.delete(:current_section)}
      end

      def handle_event(:end_element, "BookingGroup", state) do
        group = state.current_group
        section = state.current_section
        updated_section = Map.put(section, :booking_groups, [group | section.booking_groups])
        {:ok, state |> Map.put(:current_section, updated_section) |> Map.delete(:current_group)}
      end

      def handle_event(:end_element, _name, state) do
        {:ok, state}
      end

      defp find_attribute(attributes, name) do
        Enum.find_value(attributes, fn
          {^name, value} -> value
          _ -> nil
        end)
      end

      defp parse_date(text) do
        text
        |> String.split("T")
        |> List.first()
        |> Date.from_iso8601!()
      end

      defp parse_datetime(text) do
        text
        |> String.replace(~r/\+.*$/, "")
        |> NaiveDateTime.from_iso8601!()
        |> DateTime.from_naive!("Etc/UTC")
      end
    end
  end
end
