defmodule App.MiClub.Api do
  @moduledoc false
  alias App.MiClub.Auth

  require Logger

  def get_event(slug, token, event_id) do
    opts = config(slug)

    cookie = "JSESSIONID=#{token}"

    [base_url: Keyword.get(opts, :base_url)]
    |> Req.new()
    |> Req.Request.put_header("cookie", cookie)
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

    [base_url: Keyword.get(opts, :base_url)]
    |> Req.new()
    |> Req.Request.put_header("cookie", cookie)
    |> CurlReq.Plugin.attach()
    |> Req.get(url: "/spring/bookings/events/between/#{from_date()}/#{to_date()}/3000000")
    |> case do
      {:ok, %{status: 401}} ->
        {:ok, cookie} = Auth.get_cookie_by_token(token)
        {:ok, _updated_cookie} = Auth.invalidate_cookie(cookie)
        {:error, :unauthorized}

      {:ok, %{status: 200, body: body}} ->
        dbg(body)
        {:ok, body}
    end
  end

  @spec login(atom()) :: {:ok, String.t()} | {:error, term()}
  def login(slug) do
    opts = config(slug)
    user = Keyword.get(opts, :username)
    password = Keyword.get(opts, :password)

    response =
      [
        base_url: Keyword.get(opts, :base_url),
        method: :post,
        url: "/security/login.msp",
        form: %{"user" => user, "password" => password, "action" => "login", "Submit" => "Login"},
        user_agent:
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15",
        redirect: false
      ]
      |> Req.new()
      |> CurlReq.Plugin.attach()
      |> Req.request()

    case response do
      {:ok, %{status: status} = resp} when status in [302] ->
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

  defp from_date, do: DateTime.utc_now() |> DateTime.add(-5, :day) |> DateTime.to_date() |> format_date()
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

      def handle_event(:start_element, {"BookingSection", attributes}, state) do
        section = %{
          remote_id: find_attribute(attributes, "id"),
          active: nil,
          name: nil,
          booking_groups: []
        }

        {:ok, Map.put(state, :current_section, section)}
      end

      def handle_event(:start_element, {"BookingGroup", attributes}, state) do
        group = %{
          remote_id: find_attribute(attributes, "id"),
          size: find_attribute(attributes, "size"),
          active: nil,
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

      def handle_event(:start_element, {"BookingEntries", _attributes}, state) do
        {:ok, Map.put(state, :parsing_entries, true)}
      end

      def handle_event(:start_element, {"BookingEntry", attributes}, %{parsing_entries: true} = state) do
        entry = %{
          remote_id: find_attribute(attributes, "id"),
          index: find_attribute(attributes, "index"),
          entry_type: find_attribute(attributes, "type"),
          person_name: nil,
          membership_number: nil,
          gender: nil,
          handicap: nil,
          golf_link_no: nil
        }

        {:ok, Map.put(state, :current_entry, entry)}
      end

      def handle_event(:start_element, {"PersonName", _}, state) do
        {:ok, Map.put(state, :current_element, :person_name)}
      end

      def handle_event(:start_element, {"Handicap", _}, state) do
        {:ok, Map.put(state, :current_element, :handicap)}
      end

      def handle_event(:start_element, {"MembershipNumber", _}, state) do
        {:ok, Map.put(state, :current_element, :membership_number)}
      end

      def handle_event(:start_element, {"Gender", _}, state) do
        {:ok, Map.put(state, :current_element, :gender)}
      end

      def handle_event(:start_element, {"GolfLinkNo", _}, state) do
        {:ok, Map.put(state, :current_element, :golf_link_no)}
      end

      def handle_event(:start_element, {"Name", _}, state) do
        {:ok, Map.put(state, :current_element, :name)}
      end

      def handle_event(:start_element, {"Date", _}, state) do
        {:ok, Map.put(state, :current_element, :date)}
      end

      def handle_event(:start_element, {"Time", _}, state) do
        {:ok, Map.put(state, :current_element, :time)}
      end

      def handle_event(:start_element, {"StatusCode", _}, state) do
        {:ok, Map.put(state, :current_element, :status_code)}
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

      def handle_event(:start_element, _element, state) do
        {:ok, state}
      end

      # Handle character data for BookingEntry fields
      def handle_event(:characters, text, %{current_element: :person_name, current_entry: entry} = state) do
        updated_entry = Map.put(entry, :person_name, text)
        {:ok, state |> Map.put(:current_entry, updated_entry) |> Map.delete(:current_element)}
      end

      def handle_event(:characters, text, %{current_element: :handicap, current_entry: entry} = state) do
        handicap =
          case Float.parse(text) do
            {value, _} -> value
            :error -> nil
          end

        updated_entry = Map.put(entry, :handicap, handicap)
        {:ok, state |> Map.put(:current_entry, updated_entry) |> Map.delete(:current_element)}
      end

      def handle_event(:characters, text, %{current_element: :membership_number, current_entry: entry} = state) do
        updated_entry = Map.put(entry, :membership_number, text)
        {:ok, state |> Map.put(:current_entry, updated_entry) |> Map.delete(:current_element)}
      end

      def handle_event(:characters, text, %{current_element: :gender, current_entry: entry} = state) do
        updated_entry = Map.put(entry, :gender, text)
        {:ok, state |> Map.put(:current_entry, updated_entry) |> Map.delete(:current_element)}
      end

      def handle_event(:characters, text, %{current_element: :golf_link_no, current_entry: entry} = state) do
        updated_entry = Map.put(entry, :golf_link_no, text)
        {:ok, state |> Map.put(:current_entry, updated_entry) |> Map.delete(:current_element)}
      end

      # Handle character data for BookingGroup fields
      def handle_event(:characters, text, %{current_element: :time, current_group: group} = state) do
        updated_group = Map.put(group, :time, parse_time(text))
        {:ok, state |> Map.put(:current_group, updated_group) |> Map.delete(:current_element)}
      end

      def handle_event(:characters, text, %{current_element: :status_code, current_group: group} = state) do
        updated_group = Map.put(group, :status_code, text)
        {:ok, state |> Map.put(:current_group, updated_group) |> Map.delete(:current_element)}
      end

      # Handle other character data
      def handle_event(:characters, text, %{current_element: :name} = state) do
        if Map.has_key?(state, :current_section) do
          section = Map.put(state.current_section, :name, text)
          {:ok, state |> Map.put(:current_section, section) |> Map.delete(:current_element)}
        else
          {:ok, state |> Map.put(:name, text) |> Map.delete(:current_element)}
        end
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

      def handle_event(:characters, _text, state) do
        {:ok, state}
      end

      def handle_event(:end_element, "BookingEntry", %{parsing_entries: true} = state) do
        entry = state.current_entry
        group = state.current_group
        updated_group = Map.update!(group, :booking_entries, &(&1 ++ [entry]))
        {:ok, state |> Map.put(:current_group, updated_group) |> Map.delete(:current_entry)}
      end

      def handle_event(:end_element, "BookingEntries", state) do
        {:ok, Map.delete(state, :parsing_entries)}
      end

      def handle_event(:end_element, "BookingSection", state) do
        section = state.current_section
        sections = [section | state.booking_sections]
        {:ok, state |> Map.put(:booking_sections, sections) |> Map.delete(:current_section)}
      end

      def handle_event(:end_element, "BookingGroup", state) do
        group = state.current_group
        section = state.current_section
        updated_section = Map.update!(section, :booking_groups, &(&1 ++ [group]))
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

      defp parse_time(text) do
        [hours, minutes] = String.split(text, ":")
        Time.new!(String.to_integer(hours), String.to_integer(minutes), 0)
      end
    end
  end
end
