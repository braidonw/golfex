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
    GenServer.start_link(__MODULE__, args, name: via_name(args))
  end

  def init(slug) do
    opts = config(slug)
    base_url = Keyword.get(opts, :base_url)
    req = Req.new(base_url: base_url)
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
    with {:ok, resp} <- Api.login(state.req, state.username, state.password) do
      set_cookies = Req.Response.get_header(resp, "set-cookie")
      auth_cookie = set_cookies |> Enum.find(&String.contains?(&1, "JSESSIONID")) |> String.split(";") |> List.first()

      Map.update(state, :req, Req.new(), &Req.Request.put_header(&1, "cookie", auth_cookie))
    end
  end

  defp config(slug) do
    config = Application.get_env(:app, :miclub)[slug]
    [username: config[:username], password: config[:password], base_url: config[:base_url]]
  end
end
