defmodule App.MiClub.Server do
  @moduledoc false
  use GenServer

  alias App.MiClub.Api

  require Logger

  @type state :: %{
          req: Req.Request.t(),
          username: String.t(),
          password: String.t()
        }

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_name(args[:name]))
  end

  def init(opts) do
    base_url = Keyword.get(opts, :base_url)
    req = [base_url: base_url] |> Req.new() |> Req.Request.put_new_header("cookie", "JSESSIONID=")
    state = %{req: req, username: Keyword.get(opts, :username), password: Keyword.get(opts, :password)}
    {:ok, state}
  end

  def list_events(name) do
    GenServer.call(via_name(name), :list_events)
  end

  def get_event(name, event_id) do
    GenServer.call(via_name(name), {:fetch_event, event_id})
  end

  def handle_call(:list_events, _from, state) do
    state = login(state)
    events = Api.list_events(state.req)
    {:reply, events, state}
  end

  def handle_call({:fetch_event, event_id}, _from, state) do
    event =
      case Api.get_event(state.req, event_id) do
        {:ok, response} -> response.body
        {:error, reason} -> Logger.error("Failed to fetch event: #{inspect(reason)}")
      end

    {:reply, event, state}
  end

  defp via_name(name), do: {:via, Registry, {App.MiClub.Registry, name}}

  defp login(state) do
    {:ok, resp} = Api.login(state.req, state.username, state.password)
    set_cookies = Req.Response.get_header(resp, "set-cookie")
    auth_cookie = set_cookies |> Enum.find(&String.contains?(&1, "JSESSIONID")) |> String.split(";") |> List.first()
    req = Req.Request.put_header(state.req, "cookie", auth_cookie)
    Map.put(state, :req, req)
  end
end
